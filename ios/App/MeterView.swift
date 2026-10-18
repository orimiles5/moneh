import SwiftUI

struct MeterView: View {
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(spacing: Spacing.medium) {
            Text(FareFormat.string(minorUnits: 0, currencyCode: "ILS", locale: locale))
                .font(Typography.fare)
                .foregroundStyle(Palette.ink.color)
            Text("meter.idle.title")
                .font(Typography.headline)
                .foregroundStyle(Palette.inkSecondary.color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.color)
    }
}

#Preview("Light") {
    MeterView()
}

#Preview("Dark") {
    MeterView().preferredColorScheme(.dark)
}
