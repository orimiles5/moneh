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

struct TripExportTests {
    @Test func escapesFieldsAndKeepsOneRowPerTrip() {
        var trip = FareReading.idle
        trip.total = 4170
        trip.source = "booking"
        trip.invoice = FareReading.Invoice(
            number: 3, taxiNumber: "1", licenceNumber: "2", dealerName: "Cohen, \"Taxis\"",
            dealerNumber: "5", driverName: "D", driverId: "000000018"
        )
        let lines = TripExport.csv([trip]).split(separator: "\r\n")
        #expect(lines.count == 2)
        #expect(lines[0].split(separator: ",").count == TripExport.columns.count)
        #expect(lines[1].hasPrefix("3,"))
        #expect(lines[1].contains("\"Cohen, \"\"Taxis\"\"\""))
        #expect(lines[1].contains(",4170,"))
    }
}
