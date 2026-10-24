import Foundation
@testable import Moneh
import MonehCore
import Testing

@MainActor
struct ExtrasTests {
    @Test(arguments: ["he", "en"])
    func extraNamesFitTheInvoice(language: String) throws {
        // Spec 2018 Annex A, note 2: an extra's name is at most 16 characters.
        let meter = Meter(tariffId: MeterModel.tariffId)
        let bundle = try #require(Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:)))
        for id in meter.fixedPriceExtras + meter.enteredAmountExtras {
            let name = bundle.localizedString(forKey: "extra." + id, value: nil, table: nil)
            #expect(name != "extra." + id, "\(id) has no \(language) name")
            #expect(name.count <= 16, "\(id) in \(language): \(name)")
        }
    }

    @Test func typedAmountsBecomeMinorUnits() {
        #expect(FareFormat.minorUnits(Decimal(string: "12.345") ?? 0) == 1235)
        #expect(FareFormat.minorUnits(30) == 3000)
    }
}
