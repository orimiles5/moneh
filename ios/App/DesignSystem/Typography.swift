import SwiftUI

/// Heebo throughout; its digits are tabular by default, so the fare never jitters.
/// Every style scales with Dynamic Type relative to a system style.
enum Typography {
    static let fare = Font.custom("Heebo-Black", size: 96, relativeTo: .largeTitle).monospacedDigit()
    static let title = Font.custom("Heebo-Bold", size: 34, relativeTo: .title)
    static let headline = Font.custom("Heebo-Bold", size: 22, relativeTo: .headline)
    static let body = Font.custom("Heebo-Regular", size: 18, relativeTo: .body)
    static let label = Font.custom("Heebo-Medium", size: 18, relativeTo: .body)
    static let caption = Font.custom("Heebo-Regular", size: 14, relativeTo: .caption)
}
