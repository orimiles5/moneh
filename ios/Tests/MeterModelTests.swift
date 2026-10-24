import Foundation
@testable import Moneh
import Testing

@MainActor
struct MeterModelTests {
    private let store = TripStore(directory: .temporaryDirectory.appending(path: UUID().uuidString))
    private var clock = Date(timeIntervalSince1970: 1_792_317_600) // Sunday 2026-10-18 10:00 in Israel

    private func model(at date: Date, profile: IssuerProfile = IssuerProfile()) -> MeterModel {
        var lastInvoice: Int64 = 0
        return MeterModel(
            store: store,
            feed: nil,
            liveActivity: nil,
            now: { date },
            profile: { profile },
            nextInvoiceNumber: {
                lastInvoice += 1
                return lastInvoice
            }
        )
    }

    @Test func runsAndSettlesATrip() {
        let start = model(at: clock)
        start.start(vatExempt: false)
        #expect(start.reading.phase == .hired)
        #expect(start.reading.rateId == "A")

        let later = model(at: clock.addingTimeInterval(600))
        #expect(later.reading.phase == .hired, "an unfinished trip is restored on launch")
        later.stop()
        // 10 minutes at tariff A: (1056 + 10 x 165) x 1.18 = 3193.08, rounded to 0.10 ₪
        #expect(later.reading.total == 3190)
        later.settle(paymentMethod: "cash")
        #expect(later.reading.phase == .idle)
        #expect(store.archivedTripCount() == 1)
        #expect(store.loadCurrent() == nil)
    }

    @Test func eilatTripIsVatExempt() {
        let model = model(at: clock)
        model.start(vatExempt: true)
        model.stop()
        #expect(model.reading.vatExempt)
        #expect(model.reading.total == 1060)
    }

    @Test func illegalActionsAreIgnored() {
        let model = model(at: clock)
        model.stop()
        model.addExtra("booking")
        #expect(model.reading.phase == .idle)
        #expect(store.loadCurrent() == nil)
    }

    @Test func historyListsSettledTripsAndFlagsTampering() throws {
        let model = model(at: clock)
        model.start(vatExempt: false)
        model.stop()
        model.settle(paymentMethod: "cash")
        let trips = store.archivedTrips()
        #expect(trips.count == 1)
        #expect(trips.first?.reading?.phase == .settled)
        #expect(trips.first?.reading?.total == 1250) // starting fare 10.56 x 1.18 = 12.46, rounded to 0.10 ₪

        let file = try store.directory.appending(path: "archive").appending(path: #require(trips.first?.id))
        let text = try String(contentsOf: file, encoding: .utf8).replacingOccurrences(of: "Hired", with: "Hirex")
        try text.write(to: file, atomically: true, encoding: .utf8)
        #expect(store.archivedTrips().first?.reading == nil)
    }

    @Test func stoppingIssuesAnInvoiceOnlyWithCompleteDetails() {
        let anonymous = model(at: clock)
        anonymous.start(vatExempt: false)
        anonymous.stop()
        #expect(anonymous.reading.invoice == nil)
        anonymous.settle(paymentMethod: "card")

        var profile = IssuerProfile(
            taxiNumber: "1234",
            licenceNumber: "12-345-67",
            driverName: "Driver",
            driverId: "000000018"
        )
        profile.dealers = [IssuerProfile.Dealer(name: "Dealer", number: "512345678")]
        let named = model(at: clock, profile: profile)
        named.start(vatExempt: false)
        named.stop()
        #expect(named.reading.invoice?.number == 1)
        #expect(named.reading.invoice?.driverId == "000000018")
    }

    @Test(arguments: [("000000018", true), ("000000019", false), ("12345678a", false), ("1234567890", false)])
    func validatesIsraeliIds(id: String, valid: Bool) {
        #expect(IsraeliID.isValid(id) == valid)
    }

    @Test func shiftsNeedCompleteDetailsAndCloseOnlyWhenFree() {
        #expect(!model(at: clock).openShift(), "no taxi details yet")

        var profile = IssuerProfile(
            taxiNumber: "1234",
            licenceNumber: "12-345-67",
            driverName: "Driver",
            driverId: "000000018"
        )
        profile.dealers = [IssuerProfile.Dealer(name: "Dealer", number: "512345678")]
        let model = model(at: clock, profile: profile)
        #expect(model.openShift())
        #expect(model.shift?.driverId == "000000018")
        #expect(store.loadShift() == model.shift, "the open shift survives a restart")

        model.start(vatExempt: false)
        model.closeShift()
        #expect(model.shift != nil, "a shift does not close mid-trip")
        model.stop()
        model.settle(paymentMethod: "cash")
        model.closeShift()
        #expect(model.shift == nil)
        #expect(store.loadShift() == nil)
        #expect(store.allShifts().first?.closedAt != nil)
    }
}
