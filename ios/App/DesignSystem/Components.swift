import SwiftUI

/// The app's one button shape: a full-width capsule, sized for a driver's thumb at arm's length.
struct PillButton: View {
    enum Style {
        case accent, danger, quiet
    }

    let title: LocalizedStringKey
    let style: Style
    let action: () -> Void

    init(_ title: LocalizedStringKey, style: Style, action: @escaping () -> Void) {
        self.title = title
        self.style = style
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Typography.label)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, minHeight: minimumTouchTarget)
                .foregroundStyle(foreground)
                .background(background, in: Capsule())
                .shadow(
                    color: Palette.shadow.color.opacity(Elevation.cardOpacity),
                    radius: Elevation.cardRadius / 2,
                    y: Elevation.cardY / 2
                )
        }
        .buttonStyle(PressableStyle())
    }

    private var foreground: Color {
        switch style {
        case .accent: Palette.onAccent.color
        case .danger: Palette.onDanger.color
        case .quiet: Palette.ink.color
        }
    }

    private var background: Color {
        switch style {
        case .accent: Palette.accent.color
        case .danger: Palette.danger.color
        case .quiet: Palette.surface.color
        }
    }
}

/// Sinks slightly under the finger and springs back.
struct PressableStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .animation(reduceMotion ? nil : Motion.bouncy, value: configuration.isPressed)
    }
}

/// The tariff band in force, e.g. "תעריף ב׳". Slides when the band changes.
struct TariffChip: View {
    let rateId: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(LocalizedStringKey("rate." + rateId))
            .font(Typography.label)
            .foregroundStyle(Palette.ink.color)
            .padding(.horizontal, Spacing.medium)
            .padding(.vertical, Spacing.small)
            .background(Palette.surface.color, in: Capsule())
            .id(rateId)
            .transition(reduceMotion ? .opacity : .push(from: .bottom))
            .animation(reduceMotion ? nil : Motion.standard, value: rateId)
    }
}

/// A small labelled figure under the fare, such as time or distance.
struct Stat: View {
    let label: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(spacing: Spacing.tiny) {
            Text(value)
                .font(Typography.headline.monospacedDigit())
                .foregroundStyle(Palette.ink.color)
            Text(label)
                .font(Typography.caption)
                .foregroundStyle(Palette.inkSecondary.color)
        }
        .accessibilityElement(children: .combine)
    }
}
