import ActivityKit
import Foundation

/// The Live Activity's data. Small and Codable: it is serialised for every update.
struct MeterActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var displayTotal: Int64
        var currencyCode: String
        var rateId: String
        var isRunning: Bool
        /// Charged time so far; while running, the widget counts up from here on its own.
        var elapsedSeconds: Int64
        var updatedAt: Date

        /// The moment the charged time would have started had there been no pauses, for a counting-up timer.
        var timerStart: Date {
            updatedAt.addingTimeInterval(-TimeInterval(elapsedSeconds))
        }
    }
}
