@testable import Moneh
import SnapshotTesting
import SwiftUI
import XCTest

@MainActor
final class MeterViewSnapshotTests: XCTestCase {
    func testMeterView() {
        for language in [Language.hebrew, .english] {
            for style in [UIUserInterfaceStyle.light, .dark] {
                let view = MeterView(model: MeterModel(
                    store: TripStore(directory: .temporaryDirectory.appending(path: UUID().uuidString)),
                    feed: nil
                ))
                .environment(\.locale, language.locale)
                .environment(\.layoutDirection, language.direction)
                assertSnapshot(
                    of: view,
                    as: .image(
                        layout: .device(config: .iPhone13),
                        traits: UITraitCollection(userInterfaceStyle: style)
                    ),
                    named: "\(language)-\(style == .dark ? "dark" : "light")"
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
