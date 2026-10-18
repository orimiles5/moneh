import SwiftUI

/// Drivers work at night, so night mode can be forced regardless of the system setting.
enum AppearancePreference: String, CaseIterable {
    case system
    case night

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .night: .dark
        }
    }
}
