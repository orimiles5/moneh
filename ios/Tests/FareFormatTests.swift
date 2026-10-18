import Foundation
@testable import Moneh
import Testing

struct FareFormatTests {
    @Test func formatsAgorotAsShekelsInEnglish() {
        let text = FareFormat.string(minorUnits: 1246, currencyCode: "ILS", locale: Locale(identifier: "en_US"))
        #expect(text == "₪12.46")
    }

    @Test func formatsAgorotAsShekelsInHebrew() {
        let text = FareFormat.string(minorUnits: 1246, currencyCode: "ILS", locale: Locale(identifier: "he_IL"))
        #expect(text.contains("12.46"))
        #expect(text.contains("₪"))
    }
}
