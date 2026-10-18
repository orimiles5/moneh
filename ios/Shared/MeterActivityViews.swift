import SwiftUI
import WidgetKit

/// Lock Screen and expanded Dynamic Island: the fare large, tariff and time beside it.
struct MeterActivityView: View {
    let state: MeterActivityAttributes.ContentState
    @Environment(\.locale) private var locale

    var body: some View {
        HStack(alignment: .center, spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: Spacing.tiny) {
                Text(LocalizedStringKey("rate." + state.rateId))
                    .font(Typography.label)
                ElapsedText(state: state)
                    .font(Typography.headline.monospacedDigit())
            }
            .foregroundStyle(Palette.inkSecondary.color)
            Spacer(minLength: Spacing.small)
            FareText(state: state, font: Typography.title)
        }
        .padding(Spacing.medium)
    }
}

/// CarPlay Dashboard (and Apple Watch Smart Stack): the fare and tariff, nothing else, readable at a glance.
struct MeterActivitySmallView: View {
    let state: MeterActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.tiny) {
            FareText(state: state, font: Typography.title)
            Text(LocalizedStringKey(state.isRunning ? "rate." + state.rateId : "meter.paused"))
                .font(Typography.label)
                .foregroundStyle(Palette.inkSecondary.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.small)
    }
}

/// Picks the layout for the surface the system is drawing on.
struct MeterActivityContent: View {
    let state: MeterActivityAttributes.ContentState
    @Environment(\.activityFamily) private var family

    var body: some View {
        switch family {
        case .small: MeterActivitySmallView(state: state)
        default: MeterActivityView(state: state)
        }
    }
}

struct FareText: View {
    let state: MeterActivityAttributes.ContentState
    let font: Font
    @Environment(\.locale) private var locale

    var body: some View {
        Text(FareFormat.string(minorUnits: state.displayTotal, currencyCode: state.currencyCode, locale: locale))
            .font(font.monospacedDigit())
            .foregroundStyle(Palette.ink.color)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .contentTransition(.numericText(value: Double(state.displayTotal)))
    }
}

/// Counts up by itself while running, so the widget needs no update every second.
struct ElapsedText: View {
    let state: MeterActivityAttributes.ContentState

    var body: some View {
        if state.isRunning {
            Text(timerInterval: state.timerStart ... .distantFuture, countsDown: false)
        } else {
            Text(Duration.seconds(state.elapsedSeconds).formatted(.time(pattern: .minuteSecond)))
        }
    }
}
