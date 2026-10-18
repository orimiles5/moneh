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

    private(set) var reading = FareReading.idle
    private(set) var locationProblem: LocationFeed.Problem?

    @ObservationIgnored private var meter: Meter
    @ObservationIgnored private let store: TripStore
    @ObservationIgnored private let feed: LocationFeed?
    @ObservationIgnored private let liveActivity: LiveActivityController?
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var ticker: Task<Void, Never>?

    /// Pass nil [feed] and [liveActivity] to run without CoreLocation or ActivityKit (tests, previews).
    init(
        store: TripStore = .standard,
        feed: LocationFeed? = LocationFeed(),
        liveActivity: LiveActivityController? = LiveActivityController(),
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.feed = feed
        self.liveActivity = liveActivity
        self.now = now
        meter = store.loadCurrent().flatMap { Meter.companion.restore(entries: $0) } ?? Meter(tariffId: Self.tariffId)
        phaseChanged()
    }

    func start(vatExempt: Bool) {
        apply { $0.hire(atMs: $1, vatExempt: vatExempt) }
    }

    func pause() {
        apply { $0.pause(atMs: $1) }
    }

    func resume() {
        apply { $0.resume(atMs: $1) }
    }

    func stop() {
        apply { $0.stop(atMs: $1) }
    }

    func addExtra(_ id: String) {
        apply { $0.addExtra(atMs: $1, extraId: id) }
    }

    func addExtra(_ id: String, amountMinorUnits: Int64) {
        apply { $0.addExtraAmount(atMs: $1, extraId: id, amountMinorUnits: amountMinorUnits) }
    }

    /// Ends the trip and gets ready for the next one.
    func settle() {
        guard meter.settle(atMs: nowMs) else { return }
        try? store.saveCurrent(meter.entries)
        try? store.archiveCurrent(head: meter.reading(nowMs: nowMs).logHead)
        meter = Meter(tariffId: Self.tariffId)
        phaseChanged()
    }

    var tariffId: String {
        meter.tariffId
    }

    var tariffSources: [(title: String, url: URL)] {
        meter.tariffSources.compactMap { source in URL(string: source.url).map { (source.title, $0) } }
    }

    var fixedPriceExtras: [String] {
        meter.fixedPriceExtras
    }

    var enteredAmountExtras: [String] {
        meter.enteredAmountExtras
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
        let moved = meter.location(
            atMs: Int64(location.timestamp.timeIntervalSince1970 * 1000),
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            accuracyMetres: location.horizontalAccuracy,
            speedMetresPerSecond: location.speed
        )
        if moved {
            persist()
            refresh()
        }
    }

    /// Starts or stops location, the one-second ticker and the idle timer to match the trip's phase.
    private func phaseChanged() {
        refresh()
        let tracking = reading.phase == .hired || reading.phase == .paused
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
