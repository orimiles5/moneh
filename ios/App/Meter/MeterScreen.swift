import SwiftUI

struct MeterActions {
    var start: () -> Void = {}
    var pause: () -> Void = {}
    var resume: () -> Void = {}
    var stop: () -> Void = {}
    var newTrip: () -> Void = {}
    var showExtras: () -> Void = {}
}

/// The main screen: one huge fare. Pure rendering of a reading, so every state can be snapshot-tested.
struct MeterScreen: View {
    let reading: FareReading
    /// The band in force now; shown before a trip starts, when the reading has no trip yet.
    let currentRateId: String
    let locationProblem: LocationFeed.Problem?
    let actions: MeterActions

    @Environment(\.locale) private var locale
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if verticalSizeClass == .compact {
                // Landscape, as on a dashboard mount: fare on the leading side, controls on the trailing side.
                HStack(spacing: Spacing.xLarge) {
                    fareColumn
                    controls.frame(maxWidth: 320)
                }
            } else {
                VStack(spacing: Spacing.large) {
                    fareColumn
                    controls
                }
            }
        }
        .padding(Spacing.large)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Palette.background.color)
        .sensoryFeedback(.impact(weight: .heavy), trigger: reading.phase)
    }

    private var fareColumn: some View {
        VStack(spacing: Spacing.medium) {
            HStack {
                TariffChip(rateId: reading.phase == .idle ? currentRateId : reading.rateId)
                Spacer()
            }
            Spacer()
            fare
            status
            Spacer()
            if let locationProblem {
                LocationBanner(problem: locationProblem)
            }
        }
    }

    private var fare: some View {
        Text(FareFormat.string(minorUnits: reading.displayTotal, currencyCode: reading.currencyCode, locale: locale))
            .font(Typography.fare)
            .foregroundStyle(reading.phase == .idle ? Palette.inkSecondary.color : Palette.ink.color)
            .lineLimit(1)
            .minimumScaleFactor(0.3)
            .contentTransition(reduceMotion ? .identity : .numericText(value: Double(reading.displayTotal)))
            .animation(reduceMotion ? nil : Motion.standard, value: reading.displayTotal)
            .accessibilityAddTraits(.updatesFrequently)
    }

    @ViewBuilder private var status: some View {
        switch reading.phase {
        case .idle, .settled:
            Text("meter.idle.title")
                .font(Typography.headline)
                .foregroundStyle(Palette.inkSecondary.color)
        case .hired, .paused, .stopped:
            VStack(spacing: Spacing.medium) {
                if reading.phase == .paused {
                    Text("meter.paused")
                        .font(Typography.headline)
                        .foregroundStyle(Palette.inkSecondary.color)
                }
                HStack(spacing: Spacing.xxLarge) {
                    Stat(label: "meter.time", value: elapsed)
                    Stat(label: "meter.distance", value: distance)
                }
            }
        }
    }

    private var controls: some View {
        VStack(spacing: Spacing.medium) {
            switch reading.phase {
            case .idle, .settled:
                PillButton("meter.start", style: .accent, action: actions.start)
            case .hired:
                HStack(spacing: Spacing.medium) {
                    PillButton("meter.extras", style: .quiet, action: actions.showExtras)
                    PillButton("meter.pause", style: .quiet, action: actions.pause)
                }
                PillButton("meter.stop", style: .danger, action: actions.stop)
            case .paused:
                HStack(spacing: Spacing.medium) {
                    PillButton("meter.extras", style: .quiet, action: actions.showExtras)
                    PillButton("meter.resume", style: .accent, action: actions.resume)
                }
                PillButton("meter.stop", style: .danger, action: actions.stop)
            case .stopped:
                PillButton("meter.newTrip", style: .accent, action: actions.newTrip)
            }
        }
    }

    private var elapsed: String {
        let pattern: Duration.TimeFormatStyle.Pattern = reading
            .elapsed >= .seconds(3600) ? .hourMinuteSecond : .minuteSecond
        return reading.elapsed.formatted(.time(pattern: pattern).locale(locale))
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

private struct LocationBanner: View {
    let problem: LocationFeed.Problem
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: Spacing.small) {
            Text(problem == .denied ? "location.denied" : "location.servicesOff")
                .font(Typography.body)
                .foregroundStyle(Palette.ink.color)
                .multilineTextAlignment(.center)
            if problem == .denied, let url = URL(string: UIApplication.openSettingsURLString) {
                Button("location.openSettings") { openURL(url) }
                    .font(Typography.label)
                    .foregroundStyle(Palette.danger.color)
                    .frame(minHeight: minimumTouchTarget)
            }
        }
        .padding(Spacing.medium)
        .frame(maxWidth: .infinity)
        .background(Palette.surface.color, in: RoundedRectangle(cornerRadius: Radius.card))
    }
}
