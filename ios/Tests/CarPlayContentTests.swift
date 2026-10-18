import Foundation
@testable import Moneh
import Testing

struct CarPlayContentTests {
    private let english = Locale(identifier: "en_US")

    @Test func showsFareTariffTimeAndDistance() {
        var reading = FareReading.idle
        reading.phase = .hired
        reading.rateId = "B"
        reading.displayTotal = 4166
        reading.elapsed = .seconds(872)
        reading.distanceMetres = 6830
        let content = CarPlayContent(reading: reading, currentRateId: "A", locale: english)
        #expect(content.items.map(\.detail) == ["₪41.66", "Tariff B", "14:32", "6.8 km"])
        #expect(content.actions == [.pause, .stop])
    }

    @Test func offersOnlyLegalActions() {
        var reading = FareReading.idle
        #expect(CarPlayContent(reading: reading, currentRateId: "A", locale: english).actions.isEmpty)
        reading.phase = .paused
        #expect(CarPlayContent(reading: reading, currentRateId: "A", locale: english).actions == [.resume, .stop])
        reading.phase = .stopped
        #expect(CarPlayContent(reading: reading, currentRateId: "A", locale: english).actions.isEmpty)
    }

    @Test func idleShowsTheTariffInForceNow() {
        let content = CarPlayContent(reading: .idle, currentRateId: "C", locale: english)
        #expect(content.items[1].detail == "Tariff C")
    }
}
