import SwiftUI

struct MeterView: View {
    var body: some View {
        VStack(spacing: Spacing.medium) {
            Text(0, format: .number.precision(.fractionLength(2)))
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
