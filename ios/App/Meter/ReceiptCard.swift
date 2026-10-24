import SwiftUI

/// The trip summary as a slip of paper. Rendered on screen and, unchanged, into the shared image.
struct ReceiptCard: View {
    let reading: FareReading
    @Environment(\.locale) private var locale

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            VStack(alignment: .leading, spacing: Spacing.tiny) {
                Text("receipt.title")
                    .font(Typography.headline)
                if let startedAt = reading.startedAt {
                    Text(startedAt.formatted(.dateTime.day().month().year().hour().minute().locale(locale)))
                        .font(Typography.caption)
                        .foregroundStyle(Palette.inkSecondary.color)
                }
            }

            VStack(spacing: Spacing.small) {
                line("receipt.startingFare", reading.startingFare)
                line("receipt.time \(elapsed)", reading.timeCharge)
                line("receipt.distance \(distance)", reading.distanceCharge)
                if reading.extras > 0 {
                    line("receipt.extras", reading.extras)
                }
                if reading.vatExempt {
                    line("receipt.vatExempt", 0)
                } else {
                    line("receipt.vat \(vatRate)", reading.vat)
                }
                if reading.passThrough > 0 {
                    line("receipt.tolls", reading.passThrough)
                }
                if reading.rounding != 0 {
                    line("receipt.rounding", reading.rounding)
                }
            }
            .font(Typography.body)

            Divider().overlay(Palette.inkSecondary.color)

            HStack(alignment: .firstTextBaseline) {
                Text("receipt.total")
                    .font(Typography.headline)
                Spacer()
                Text(money(reading.total))
                    .font(Typography.title.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }

            VStack(alignment: .leading, spacing: Spacing.tiny) {
                Text("receipt.tripId \(String(reading.logHead.prefix(12)))")
                    .font(Typography.caption.monospaced())
                Text("receipt.disclaimer")
                    .font(Typography.caption)
            }
            .foregroundStyle(Palette.inkSecondary.color)
        }
        .foregroundStyle(Palette.ink.color)
        .padding(Spacing.large)
        .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: Radius.chip))
        .shadow(
            color: Palette.shadow.color.opacity(Elevation.cardOpacity),
            radius: Elevation.cardRadius,
            y: Elevation.cardY
        )
    }

    private func line(_ label: LocalizedStringKey, _ amount: Int64) -> some View {
        HStack {
            Text(label)
            Spacer()
            Text(money(amount)).monospacedDigit()
        }
    }

    private func money(_ minorUnits: Int64) -> String {
        FareFormat.string(minorUnits: minorUnits, currencyCode: reading.currencyCode, locale: locale)
    }

    private var vatRate: String {
        (Double(reading.vatBasisPoints) / 10000).formatted(.percent.locale(locale))
    }

    private var elapsed: String {
        reading.elapsed
            .formatted(.time(pattern: reading.elapsed >= .seconds(3600) ? .hourMinuteSecond : .minuteSecond)
                .locale(locale))
    }

    private var distance: String {
        Measurement(value: Double(reading.distanceMetres) / 1000, unit: UnitLength.kilometers)
            .formatted(.measurement(
                width: .abbreviated,
                usage: .asProvided,
                numberFormatStyle: .number.precision(.fractionLength(1))
            ).locale(locale))
    }
}

/// Slides the receipt out of a slot at the top of the screen, like a printer, then offers to share it.
struct ReceiptSlot: View {
    let reading: FareReading
    let onNewTrip: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var printed: Bool

    /// [alreadyPrinted] skips the slide-out, for snapshots.
    init(reading: FareReading, onNewTrip: @escaping () -> Void, alreadyPrinted: Bool = false) {
        self.reading = reading
        self.onNewTrip = onNewTrip
        _printed = State(initialValue: alreadyPrinted)
    }

    var body: some View {
        VStack(spacing: Spacing.large) {
            VStack(spacing: 0) {
                Capsule()
                    .fill(Palette.ink.color)
                    .frame(height: 6)
                    .zIndex(1)
                ReceiptCard(reading: reading)
                    .padding(.horizontal, Spacing.small)
                    .offset(y: printed ? 0 : -600)
                    .clipped()
            }
            .clipped()
            Spacer(minLength: 0)
            ReceiptShareButton(reading: reading)
            PillButton("meter.newTrip", style: .accent, action: onNewTrip)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.9, dampingFraction: 0.85)) { printed = true }
        }
        .sensoryFeedback(.success, trigger: printed)
    }
}

/// Shares the receipt as an image, drawn exactly as it appears on screen.
struct ReceiptShareButton: View {
    let reading: FareReading

    @Environment(\.locale) private var locale
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        if let image = renderedImage {
            ShareLink(item: image, preview: SharePreview(Text("receipt.title"), image: image)) {
                Text("receipt.share")
                    .font(Typography.label)
                    .frame(maxWidth: .infinity, minHeight: minimumTouchTarget)
                    .foregroundStyle(Palette.ink.color)
                    .background(Palette.surface.color, in: Capsule())
            }
            .buttonStyle(PressableStyle())
        }
    }

    private var renderedImage: Image? {
        let renderer = ImageRenderer(
            content: ReceiptCard(reading: reading)
                .frame(width: 360)
                .padding(Spacing.medium)
                .background(Palette.background.color)
                .environment(\.locale, locale)
                .environment(\.layoutDirection, layoutDirection)
                .environment(\.colorScheme, colorScheme)
        )
        renderer.scale = displayScale
        return renderer.uiImage.map { Image(uiImage: $0) }
    }
}
