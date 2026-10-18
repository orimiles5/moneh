@testable import Moneh
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class MeterScreenSnapshotTests: XCTestCase {
    private static let running: FareReading = {
        var reading = FareReading.idle
        reading.phase = .hired
        reading.rateId = "B"
        reading.displayTotal = 4166
        reading.elapsed = .seconds(14 * 60 + 32)
        reading.distanceMetres = 6830
        return reading
    }()

    func testIdle() {
        assertAllVariants(.idle)
    }

    func testRunning() {
        assertAllVariants(Self.running)
    }

    func testPaused() {
        var reading = Self.running
        reading.phase = .paused
        assertAllVariants(reading)
    }

    func testRunningLandscape() {
        assertSnapshot(
            of: screen(Self.running, language: .hebrew),
            as: .image(
                layout: .device(config: .iPhone13(.landscape)),
                traits: UITraitCollection(userInterfaceStyle: .dark)
            )
        )
    }

    private func screen(_ reading: FareReading, language: Language) -> some View {
        MeterScreen(reading: reading, currentRateId: "A", locationProblem: nil, actions: MeterActions())
            .environment(\.locale, language.locale)
            .environment(\.layoutDirection, language.direction)
    }

    private func assertAllVariants(_ reading: FareReading, testName: String = #function) {
        for language in [Language.hebrew, .english] {
            for style in [UIUserInterfaceStyle.light, .dark] {
                assertSnapshot(
                    of: screen(reading, language: language),
                    as: .image(
                        layout: .device(config: .iPhone13),
                        traits: UITraitCollection(userInterfaceStyle: style)
                    ),
                    named: "\(language)-\(style == .dark ? "dark" : "light")",
                    testName: testName
                )
            }
        }
    }
}

enum Language: String, CustomStringConvertible {
    case hebrew = "he_IL"
    case english = "en_US"

    var locale: Locale {
        Locale(identifier: rawValue)
    }

    var direction: LayoutDirection {
        self == .hebrew ? .rightToLeft : .leftToRight
    }

    var description: String {
        self == .hebrew ? "he" : "en"
    }
}
