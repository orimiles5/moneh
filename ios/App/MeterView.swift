import SwiftUI

struct MeterView: View {
    let model: MeterModel
    @Environment(\.locale) private var locale
    @AppStorage("vatExempt") private var vatExempt = false

    var body: some View {
        VStack(spacing: Spacing.large) {
            Spacer()
            Text(FareFormat.string(
                minorUnits: model.reading.displayTotal,
                currencyCode: model.reading.currencyCode,
                locale: locale
            ))
            .font(Typography.fare)
            .foregroundStyle(Palette.ink.color)
            if model.reading.phase == .idle {
                Text("meter.idle.title")
                    .font(Typography.headline)
                    .foregroundStyle(Palette.inkSecondary.color)
            }
            Spacer()
            action
        }
        .padding(Spacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.color)
    }

    @ViewBuilder private var action: some View {
        switch model.reading.phase {
        case .idle, .settled:
            PillButton("meter.start", style: .accent) { model.start(vatExempt: vatExempt) }
        case .hired, .paused:
            PillButton("meter.stop", style: .danger) { model.stop() }
        case .stopped:
            PillButton("meter.newTrip", style: .accent) { model.settle() }
        }
    }
}

struct PillButton: View {
    enum Style {
        case accent, danger
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
                .frame(maxWidth: .infinity, minHeight: minimumTouchTarget)
                .foregroundStyle((style == .accent ? Palette.onAccent : Palette.onDanger).color)
                .background((style == .accent ? Palette.accent : Palette.danger).color, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview("Idle") {
    MeterView(model: MeterModel(store: TripStore(directory: .temporaryDirectory), feed: nil))
}
