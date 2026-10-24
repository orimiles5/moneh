import Foundation

/// What the CarPlay screen shows for a reading, as plain values so it can be tested without CarPlay.
struct CarPlayContent: Equatable {
    struct Item: Equatable {
        let title: String
        let detail: String
    }

    enum Action: Equatable {
        case resume, stop
    }

    let items: [Item]
    let actions: [Action]

    init(reading: FareReading, currentRateId: String, locale: Locale) {
        let bundle = Bundle.main
        func text(_ key: String) -> String {
            String(
                localized: String.LocalizationValue(key),
                bundle: bundle,
                locale: locale
            )
        }
        let rateId = reading.phase == .idle || reading.phase == .settled ? currentRateId : reading.rateId
        items = [
            Item(
                title: text("carplay.fare"),
                detail: FareFormat.string(
                    minorUnits: reading.displayTotal,
                    currencyCode: reading.currencyCode,
                    locale: locale
                )
            ),
            Item(title: text("carplay.tariff"), detail: text("rate." + rateId)),
            Item(
                title: text("meter.time"),
                detail: reading.elapsed.formatted(.time(pattern: .minuteSecond).locale(locale))
            ),
            Item(
                title: text("meter.distance"),
                detail: Measurement(value: Double(reading.distanceMetres) / 1000, unit: UnitLength.kilometers)
                    // As provided: a per-kilometre tariff shows kilometres, never miles.
                    .formatted(.measurement(
                        width: .abbreviated,
                        usage: .asProvided,
                        numberFormatStyle: .number.precision(.fractionLength(1))
                    ).locale(locale))
            ),
        ]
        // Starting a trip and extras stay on the phone; while driving, only stop (and resume for a trip paused by an
        // earlier version).
        actions = switch reading.phase {
        case .hired: [.stop]
        case .paused: [.resume, .stop]
        case .idle, .stopped, .settled: []
        }
    }
}
