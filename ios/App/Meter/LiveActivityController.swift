import ActivityKit
import Foundation

/// Mirrors the running trip into a Live Activity (Lock Screen, Dynamic Island, CarPlay Dashboard).
/// Updates are local, from the app that background location keeps alive, and throttled to save energy:
/// the timer counts by itself, so only the fare needs pushing.
@MainActor
final class LiveActivityController {
    private var activity: Activity<MeterActivityAttributes>?
    private var lastPushed: (state: MeterActivityAttributes.ContentState, at: Date)?
    private let minimumInterval: TimeInterval = 5

    /// How long the final fare stays visible after the meter stops.
    private let finalFareLinger: TimeInterval = 15 * 60

    init() {
        // A trip restored after relaunch reattaches to the activity it started.
        activity = Activity<MeterActivityAttributes>.activities.first
    }

    func update(with reading: FareReading, now: Date) {
        switch reading.phase {
        case .hired, .paused:
            let state = Self.state(for: reading, now: now)
            if activity == nil {
                start(state)
            } else if Self.shouldPush(state, after: lastPushed, now: now, minimumInterval: minimumInterval) {
                push(state, now: now)
            }
        case .stopped:
            end(final: Self.state(for: reading, now: now), dismissAfter: now.addingTimeInterval(finalFareLinger))
        case .idle, .settled:
            end(final: nil, dismissAfter: now)
        }
    }

    static func state(for reading: FareReading, now: Date) -> MeterActivityAttributes.ContentState {
        MeterActivityAttributes.ContentState(
            displayTotal: reading.displayTotal,
            currencyCode: reading.currencyCode,
            rateId: reading.rateId,
            isRunning: reading.phase == .hired,
            elapsedSeconds: reading.elapsed.components.seconds,
            updatedAt: now
        )
    }

    /// Pause/resume and tariff changes go out at once; fare changes at most every [minimumInterval].
    static func shouldPush(
        _ state: MeterActivityAttributes.ContentState,
        after last: (state: MeterActivityAttributes.ContentState, at: Date)?,
        now: Date,
        minimumInterval: TimeInterval
    ) -> Bool {
        guard let last else { return true }
        if state.isRunning != last.state.isRunning || state.rateId != last.state.rateId {
            return true
        }
        return state.displayTotal != last.state.displayTotal && now.timeIntervalSince(last.at) >= minimumInterval
    }

    private func start(_ state: MeterActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        activity = try? Activity.request(
            attributes: MeterActivityAttributes(),
            content: ActivityContent(state: state, staleDate: nil)
        )
        lastPushed = (state, state.updatedAt)
    }

    private func push(_ state: MeterActivityAttributes.ContentState, now: Date) {
        guard let id = activity?.id else { return }
        lastPushed = (state, now)
        Task.detached { await Self.activity(id)?.update(ActivityContent(state: state, staleDate: nil)) }
    }

    private func end(final state: MeterActivityAttributes.ContentState?, dismissAfter date: Date) {
        guard let id = activity?.id else { return }
        activity = nil
        lastPushed = nil
        let content = state.map { ActivityContent(state: $0, staleDate: nil) }
        Task.detached { await Self.activity(id)?.end(content, dismissalPolicy: .after(date)) }
    }

    /// Activities are not Sendable, so tasks look them up by id rather than capturing them.
    private nonisolated static func activity(_ id: String) -> Activity<MeterActivityAttributes>? {
        Activity<MeterActivityAttributes>.activities.first { $0.id == id }
    }
}
