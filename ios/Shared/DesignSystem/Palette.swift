import SwiftUI
import UIKit

/// A color with explicit light and dark values, as 0xRRGGBB.
struct DynamicColor: Sendable {
    let light: UInt32
    let dark: UInt32

    var color: Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light) })
    }
}

/// Warm cream by day, warm near-black by night. Dark values are dimmed to avoid glare in a car at night.
enum Palette {
    static let background = DynamicColor(light: 0xF6F2EC, dark: 0x12100D)
    static let surface = DynamicColor(light: 0xFFFDF9, dark: 0x1E1B17)
    static let ink = DynamicColor(light: 0x1E1B17, dark: 0xEDE4D3)
    static let inkSecondary = DynamicColor(light: 0x5E574E, dark: 0xA0968A)
    static let accent = DynamicColor(light: 0xE3A23B, dark: 0xD99A3A)
    static let onAccent = DynamicColor(light: 0x1E1B17, dark: 0x12100D)
    static let danger = DynamicColor(light: 0xB23A24, dark: 0xD0583F)
    static let onDanger = DynamicColor(light: 0xFFFDF9, dark: 0x12100D)
    static let shadow = DynamicColor(light: 0x3B2F20, dark: 0x000000)
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
