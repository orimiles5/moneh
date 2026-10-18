import Foundation
@testable import Moneh
import Testing

@MainActor
struct LiveActivityTests {
    private let start = Date(timeIntervalSince1970: 1_792_317_600)

    private func state(total: Int64, rate: String = "A", running: Bool = true) -> MeterActivityAttributes.ContentState {
        .init(
            displayTotal: total,
            currencyCode: "ILS",
            rateId: rate,
            isRunning: running,
            elapsedSeconds: 0,
            updatedAt: start
        )
    }

    private func push(_ state: MeterActivityAttributes.ContentState, secondsAfter: TimeInterval) -> Bool {
        LiveActivityController.shouldPush(
            state,
            after: (self.state(total: 1000), start),
            now: start.addingTimeInterval(secondsAfter),
            minimumInterval: 5
        )
    }

    @Test func fareChangesAreThrottled() {
        #expect(!push(state(total: 1010), secondsAfter: 2))
        #expect(push(state(total: 1010), secondsAfter: 5))
        #expect(!push(state(total: 1000), secondsAfter: 60), "nothing changed")
    }

    @Test func pauseAndTariffChangesGoOutImmediately() {
        #expect(push(state(total: 1000, running: false), secondsAfter: 1))
        #expect(push(state(total: 1000, rate: "B"), secondsAfter: 1))
    }

    @Test func mapsTheReading() {
        var reading = FareReading.idle
        reading.phase = .paused
        reading.displayTotal = 4166
        reading.rateId = "B"
        reading.elapsed = .seconds(872)
        let state = LiveActivityController.state(for: reading, now: start)
        #expect(state.displayTotal == 4166)
        #expect(!state.isRunning)
        #expect(state.timerStart == start.addingTimeInterval(-872))
    }
}
