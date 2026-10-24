import CoreLocation
import MonehCore
import Observation
import UIKit

/// Drives one trip at a time: forwards user actions and location fixes to the core Meter,
/// persists after every change, and republishes the reading for the UI.
@MainActor
@Observable
final class MeterModel {
    // ponytail: one bundled tariff; pick by effective date once the next one ships (before 1.4.2027).
    static let tariffId = "il-2026-04"

    /// The one live meter, shared by the phone UI and the CarPlay scene.
    static let shared = MeterModel()

    private(set) var reading = FareReading.idle
    private(set) var locationProblem: LocationFeed.Problem?
    /// The open shift; trips start only within one.
    private(set) var shift: Shift?

    @ObservationIgnored private var meter: Meter
    @ObservationIgnored private let store: TripStore
    @ObservationIgnored private let feed: LocationFeed?
    @ObservationIgnored private let liveActivity: LiveActivityController?
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let profile: () -> IssuerProfile
    @ObservationIgnored private let nextInvoiceNumber: () -> Int64
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private let odometer = Odometer()

    /// Pass nil [feed] and [liveActivity] to run without CoreLocation or ActivityKit (tests, previews).
    init(
        store: TripStore = .standard,
        feed: LocationFeed? = LocationFeed(),
        liveActivity: LiveActivityController? = LiveActivityController(),
        now: @escaping () -> Date = Date.init,
        profile: @escaping () -> IssuerProfile = { IssuerProfile.load() },
        nextInvoiceNumber: @escaping () -> Int64 = { InvoiceSequence.next() }
    ) {
        self.profile = profile
        self.nextInvoiceNumber = nextInvoiceNumber
        self.store = store
        self.feed = feed
        self.liveActivity = liveActivity
        self.now = now
        meter = store.loadCurrent().flatMap { Meter.companion.restore(entries: $0) } ?? Meter(tariffId: Self.tariffId)
        shift = store.loadShift()
        store.recordSeal(.tariff, Self.tariffId, at: now())
        phaseChanged()
    }

    func start(vatExempt: Bool) {
        apply { $0.hire(atMs: $1, vatExempt: vatExempt) }
    }

    func start(vatExempt: Bool, agreedPrice: Int64) {
        apply { $0.hireAtAgreedPrice(atMs: $1, vatExempt: vatExempt, agreedPriceMinorUnits: agreedPrice) }
    }

    func discount(percentBasisPoints: Int32) {
        apply { $0.discountPercent(atMs: $1, basisPoints: percentBasisPoints) }
    }

    func discount(amountMinorUnits: Int64) {
        apply { $0.discountAmount(atMs: $1, amountMinorUnits: amountMinorUnits) }
    }

    func resume() {
        apply { $0.resume(atMs: $1) }
    }

    /// Hired to payment, issuing the invoice the first time (spec 2018 §8.1.7). Without complete taxi details there is
    /// no invoice.
    func stop() {
        apply { meter, now in
            guard meter.stop(atMs: now) else { return false }
            let profile = profile()
            if profile.isComplete, let dealer = profile.dealer, meter.reading(nowMs: now).invoice == nil {
                _ = meter.issueInvoice(
                    atMs: now,
                    number: nextInvoiceNumber(),
                    taxiNumber: profile.taxiNumber,
                    licenceNumber: profile.licenceNumber,
                    dealerName: dealer.name,
                    dealerNumber: dealer.number,
                    driverName: profile.driverName,
                    driverId: profile.driverId
                )
            }
            return true
        }
    }

    func addExtra(_ id: String) {
        apply { $0.addExtra(atMs: $1, extraId: id) }
    }

    func addExtra(_ id: String, amountMinorUnits: Int64) {
        apply { $0.addExtraAmount(atMs: $1, extraId: id, amountMinorUnits: amountMinorUnits) }
    }

    func removeExtra(_ id: String) {
        apply { $0.removeExtra(atMs: $1, extraId: id) }
    }

    /// Ends the trip and gets ready for the next one.
    /// Opens a shift for the identified driver (identification happens in the view). False without complete taxi
    /// details.
    @discardableResult
    func openShift() -> Bool {
        let profile = profile()
        guard shift == nil, profile.isComplete, let dealer = profile.dealer else { return false }
        let opened = Shift(
            openedAt: now(),
            taxiNumber: profile.taxiNumber,
            licenceNumber: profile.licenceNumber,
            dealerName: dealer.name,
            dealerNumber: dealer.number,
            driverName: profile.driverName,
            driverId: profile.driverId
        )
        try? store.saveShift(opened)
        store.recordSeal(.licence, profile.licenceNumber, at: opened.openedAt)
        shift = opened
        phaseChanged()
        return true
    }

    /// Closes the shift; only while free (spec 2018 §8.3.4).
    func closeShift() {
        guard var closing = shift, reading.phase == .idle || reading.phase == .settled else { return }
        closing.closedAt = now()
        try? store.closeShift(closing)
        shift = nil
        phaseChanged()
    }

    /// Payment to free, recording "cash" or "card" for the shift summary.
    func settle(paymentMethod: String) {
        guard meter.settlePaid(atMs: nowMs, paymentMethod: paymentMethod) else { return }
        try? store.saveCurrent(meter.entries)
        try? store.archiveCurrent(head: meter.reading(nowMs: nowMs).logHead)
        meter = Meter(tariffId: Self.tariffId)
        phaseChanged()
    }

    var rateReport: [RateReport] {
        meter.rateReport
    }

    var tariffId: String {
        meter.tariffId
    }

    var tariffSources: [(title: String, url: URL)] {
        meter.tariffSources.compactMap { source in URL(string: source.url).map { (source.title, $0) } }
    }

    /// Views pick up new counts through `reading`, which changes, which every added extra does.
    var extras: [ExtraItem] {
        (meter.fixedPriceExtras + meter.enteredAmountExtras).map { id in
            ExtraItem(
                id: id,
                passengerPrice: meter.extraPassengerPrice(extraId: id)?.int64Value,
                count: Int(meter.extraCount(extraId: id))
            )
        }
    }

    /// The tariff band in force now, for the idle screen.
    var currentRateId: String {
        meter.rateIdAt(nowMs: nowMs)
    }

    private var nowMs: Int64 {
        Int64(now().timeIntervalSince1970 * 1000)
    }

    private func apply(_ action: (Meter, Int64) -> Bool) {
        guard action(meter, nowMs) else { return }
        persist()
        phaseChanged()
    }

    private func persist() {
        try? store.saveCurrent(meter.entries)
    }

    private func refresh() {
        reading = FareReading(meter.reading(nowMs: nowMs))
        liveActivity?.update(with: reading, now: now())
    }

    private func receive(_ location: CLLocation) {
        let atMs = Int64(location.timestamp.timeIntervalSince1970 * 1000)
        if var open = shift {
            let metres = odometer.add(
                atMs: atMs,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                accuracyMetres: location.horizontalAccuracy,
                speedMetresPerSecond: location.speed
            )
            if metres > 0 {
                open.drivenMetres += metres
                shift = open
                try? store.saveShift(open)
            }
        }
        let moved = meter.location(
            atMs: atMs,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            accuracyMetres: location.horizontalAccuracy,
            speedMetresPerSecond: location.speed
        )
        guard moved else { return }
        persist()
        if FareReading.Phase(meter.phase) == reading.phase {
            refresh()
        } else {
            phaseChanged()
        }
    }

    /// Starts or stops location, the one-second ticker and the idle timer to match the trip's phase.
    private func phaseChanged() {
        refresh()
        // Payment keeps listening: driving on returns the meter to hired. An open shift counts every metre driven.
        let tracking = shift != nil || [.hired, .paused, .stopped].contains(reading.phase)
        UIApplication.shared.isIdleTimerDisabled = tracking
        if tracking {
            feed?.start(
                onFix: { [weak self] in self?.receive($0) },
                onProblem: { [weak self] in self?.locationProblem = $0 }
            )
        } else {
            feed?.stop()
            locationProblem = nil
        }
        ticker?.cancel()
        ticker = nil
        if reading.phase == .hired {
            ticker = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    guard let self else { return }
                    refresh()
                }
            }
        }
    }
}
