import SwiftUI

struct MeterActions {
    var start: () -> Void = {}
    var resume: () -> Void = {}
    var stop: () -> Void = {}
    var newTrip: () -> Void = {}
    var showExtras: () -> Void = {}
    var showSettings: () -> Void = {}
    var showHistory: () -> Void = {}
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
            if reading.phase == .stopped {
                ReceiptSlot(reading: reading, onNewTrip: actions.newTrip)
            } else if verticalSizeClass == .compact {
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
                if reading.phase == .idle || reading.phase == .settled {
                    Button(action: actions.showHistory) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title2)
                            .foregroundStyle(Palette.inkSecondary.color)
                            .frame(width: minimumTouchTarget, height: minimumTouchTarget)
                    }
                    .accessibilityLabel(Text("history.title"))
                    Button(action: actions.showSettings) {
                        Image(systemName: "gearshape.fill")
                            .font(.title2)
                            .foregroundStyle(Palette.inkSecondary.color)
                            .frame(width: minimumTouchTarget, height: minimumTouchTarget)
                    }
                    .accessibilityLabel(Text("settings.open"))
                }
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

    /// Spec 2018 §8.2.3–8.2.4: the price display shows the fare without extras; extras have their own labelled display.
    private var fare: some View {
        VStack(spacing: Spacing.small) {
            Text("meter.fare.label")
                .font(Typography.label)
                .foregroundStyle(Palette.inkSecondary.color)
            fareAmount
            if reading.displayExtras > 0 {
                HStack(spacing: Spacing.small) {
                    Text("meter.extras")
                    Text(FareFormat.string(
                        minorUnits: reading.displayExtras,
                        currencyCode: reading.currencyCode,
                        locale: locale
                    ))
                    .monospacedDigit()
                }
                .font(Typography.headline)
                .foregroundStyle(Palette.ink.color)
            }
        }
    }

    private var fareAmount: some View {
        Text(FareFormat.string(minorUnits: reading.displayFare, currencyCode: reading.currencyCode, locale: locale))
            .font(Typography.fare)
            .foregroundStyle(reading.phase == .idle ? Palette.inkSecondary.color : Palette.ink.color)
            .lineLimit(1)
            .minimumScaleFactor(0.3)
            .contentTransition(reduceMotion ? .identity : .numericText(value: Double(reading.displayFare)))
            .animation(reduceMotion ? nil : Motion.standard, value: reading.displayFare)
            .accessibilityAddTraits(.updatesFrequently)
    }

    @ViewBuilder private var status: some View {
        switch reading.phase {
        case .idle, .settled:
            Text("meter.state.free")
                .font(Typography.headline)
                .foregroundStyle(Palette.inkSecondary.color)
        case .hired, .paused, .stopped:
            VStack(spacing: Spacing.medium) {
                Text(reading.phase == .paused ? "meter.paused" : "meter.state.hired")
                    .font(Typography.headline)
                    .foregroundStyle(Palette.inkSecondary.color)
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
                PillButton("meter.extras", style: .quiet, action: actions.showExtras)
                PillButton("meter.stop", style: .danger, action: actions.stop)
            case .paused: // Only a trip paused by an earlier version.
                HStack(spacing: Spacing.medium) {
                    PillButton("meter.extras", style: .quiet, action: actions.showExtras)
                    PillButton("meter.resume", style: .accent, action: actions.resume)
                }
                PillButton("meter.stop", style: .danger, action: actions.stop)
            case .stopped:
                EmptyView() // The receipt takes over the whole screen.
            }
        }
    }

    private var elapsed: String {
        // Spec 2018 §8.2.5: MM:SS under an hour, HH:MM from an hour.
        let pattern: Duration.TimeFormatStyle.Pattern = reading
            .elapsed >= .seconds(3600) ? .hourMinute(padHourToLength: 2) : .minuteSecond
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
