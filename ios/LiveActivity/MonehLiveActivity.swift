import ActivityKit
import SwiftUI
import WidgetKit

@main
struct MonehWidgets: WidgetBundle {
    var body: some Widget {
        MeterLiveActivity()
    }
}

struct MeterLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MeterActivityAttributes.self) { context in
            MeterActivityContent(state: context.state)
                .activityBackgroundTint(Palette.background.color)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    MeterActivityView(state: context.state)
                }
            } compactLeading: {
                Text(LocalizedStringKey("rate." + context.state.rateId))
                    .font(Typography.caption)
            } compactTrailing: {
                FareText(state: context.state, font: Typography.label)
            } minimal: {
                Image(systemName: context.state.isRunning ? "car.fill" : "pause.fill")
            }
        }
        // CarPlay Dashboard and the Watch Smart Stack use the small layout instead of the compact Dynamic Island views.
        .supplementalActivityFamilies([.small])
    }
}
