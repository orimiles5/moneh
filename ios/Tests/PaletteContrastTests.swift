import Foundation
@testable import Moneh
import Testing

struct PaletteContrastTests {
    struct Pair: Sendable {
        let name: String
        let foreground: DynamicColor
        let background: DynamicColor
        let minimum: Double

        init(_ name: String, _ foreground: DynamicColor, _ background: DynamicColor, _ minimum: Double) {
            self.name = name
            self.foreground = foreground
            self.background = background
            self.minimum = minimum
        }
    }

    static let pairs: [Pair] = [
        Pair("ink on background", Palette.ink, Palette.background, 7),
        Pair("ink on surface", Palette.ink, Palette.surface, 7),
        Pair("secondary on background", Palette.inkSecondary, Palette.background, 4.5),
        Pair("secondary on surface", Palette.inkSecondary, Palette.surface, 4.5),
        Pair("on accent", Palette.onAccent, Palette.accent, 4.5),
        Pair("on danger", Palette.onDanger, Palette.danger, 4.5),
    ]

    @Test(arguments: pairs.indices)
    func meetsWCAGContrast(index: Int) {
        let pair = Self.pairs[index]
        #expect(contrast(pair.foreground.light, pair.background.light) >= pair.minimum, "\(pair.name) light")
        #expect(contrast(pair.foreground.dark, pair.background.dark) >= pair.minimum, "\(pair.name) dark")
    }

    private func contrast(_ lhs: UInt32, _ rhs: UInt32) -> Double {
        let lighter = max(luminance(lhs), luminance(rhs))
        let darker = min(luminance(lhs), luminance(rhs))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private func luminance(_ hex: UInt32) -> Double {
        func channel(_ shift: UInt32) -> Double {
            let value = Double((hex >> shift) & 0xFF) / 255
            return value <= 0.039_28 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0)
    }
}
