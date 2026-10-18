import Foundation
@testable import Moneh
import Testing

@MainActor
struct MeterModelTests {
    private let store = TripStore(directory: .temporaryDirectory.appending(path: UUID().uuidString))
    private var clock = Date(timeIntervalSince1970: 1_792_317_600) // Sunday 2026-10-18 10:00 in Israel

    private func model(at date: Date) -> MeterModel {
        MeterModel(store: store, feed: nil, liveActivity: nil, now: { date })
    }

    @Test func runsAndSettlesATrip() {
        let start = model(at: clock)
        start.start(vatExempt: false)
        #expect(start.reading.phase == .hired)
        #expect(start.reading.rateId == "A")

        let later = model(at: clock.addingTimeInterval(600))
        #expect(later.reading.phase == .hired, "an unfinished trip is restored on launch")
        later.stop()
        // 10 minutes at tariff A: (1056 + 10 x 165) x 1.18 = 3193.08
        #expect(later.reading.total == 3193)
        later.settle()
        #expect(later.reading.phase == .idle)
        #expect(store.archivedTripCount() == 1)
        #expect(store.loadCurrent() == nil)
    }

    @Test func eilatTripIsVatExempt() {
        let model = model(at: clock)
        model.start(vatExempt: true)
        model.stop()
        #expect(model.reading.vatExempt)
        #expect(model.reading.total == 1056)
    }

    @Test func illegalActionsAreIgnored() {
        let model = model(at: clock)
        model.stop()
        model.addExtra("booking")
        #expect(model.reading.phase == .idle)
        #expect(store.loadCurrent() == nil)
    }
}
