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

    func testReceipt() {
        var reading = Self.running
        reading.phase = .stopped
        reading.startingFare = 1056
        reading.timeCharge = 2877
        reading.distanceCharge = 1352
        reading.extras = 490
        reading.vat = 1042
        reading.passThrough = 1200
        reading.total = 8017
        reading.startedAt = Date(timeIntervalSince1970: 1_792_317_600)
        reading.logHead = "f9fbfa80ff0bb52867f60476cb2b24107e37acd0054d95951f23ee16e4f09e5b"
        assertAllVariants(reading) { reading in
            ReceiptSlot(reading: reading, onNewTrip: {}, alreadyPrinted: true)
                .padding(Spacing.large)
                .background(Palette.background.color)
        }
    }

    func testOnboarding() {
        for page in OnboardingView.Page.allCases {
            assertAllVariants(.idle, testName: "testOnboarding-\(page)") { _ in
                OnboardingView(startingAt: page) {}
            }
        }
    }

    func testSettings() {
        let sources = [(
            title: "צו פיקוח על מחירי מצרכים ושירותים (מחירי נסיעה במוניות), התשע\"ח-2018",
            url: URL(filePath: "/")
        )]
        assertAllVariants(.idle) { _ in SettingsView(tariffId: "il-2026-04", tariffSources: sources) }
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
        localized(
            MeterScreen(reading: reading, currentRateId: "A", locationProblem: nil, actions: MeterActions()),
            language
        )
    }

    private func localized(_ view: some View, _ language: Language) -> some View {
        view
            .environment(\.locale, language.locale)
            .environment(\.layoutDirection, language.direction)
    }

    private func assertAllVariants(_ reading: FareReading, testName: String = #function) {
        assertAllVariants(reading, testName: testName) { reading in
            MeterScreen(reading: reading, currentRateId: "A", locationProblem: nil, actions: MeterActions())
        }
    }

    private func assertAllVariants(
        _ reading: FareReading,
        testName: String = #function,
        @ViewBuilder content: (FareReading) -> some View
    ) {
        for language in [Language.hebrew, .english] {
            for style in [UIUserInterfaceStyle.light, .dark] {
                assertSnapshot(
                    of: localized(content(reading), language),
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
