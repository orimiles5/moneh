import SwiftUI

enum Spacing {
    static let tiny: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let xLarge: CGFloat = 32
    static let xxLarge: CGFloat = 48
}

enum Radius {
    static let card: CGFloat = 24
    static let chip: CGFloat = 12
}

/// Drivers tap at arm's length, often while moving; well above the 44pt HIG minimum.
let minimumTouchTarget: CGFloat = 64

enum Motion {
    static let standard = Animation.spring(response: 0.35, dampingFraction: 0.85)
    static let bouncy = Animation.spring(response: 0.45, dampingFraction: 0.6)
    static let quick = Animation.easeOut(duration: 0.15)
}

enum Elevation {
    static let cardRadius: CGFloat = 16
    static let cardY: CGFloat = 6
    static let cardOpacity = 0.12
}
