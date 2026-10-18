import Foundation
import MonehCore

/// A Swift copy of the core's MeterReading, so views and snapshot tests never depend on Kotlin types.
struct FareReading: Equatable {
    enum Phase {
        case idle, hired, paused, stopped, settled
    }

    var phase: Phase
    var currencyCode: String
    var rateId: String
    var displayTotal: Int64
    var total: Int64
    var startingFare: Int64
    var timeCharge: Int64
    var distanceCharge: Int64
    var extras: Int64
    var vat: Int64
    var passThrough: Int64
    var elapsed: Duration
    var distanceMetres: Int64
    var vatExempt: Bool
    var logHead: String

    static let idle = FareReading(
        phase: .idle, currencyCode: "ILS", rateId: "A", displayTotal: 0, total: 0, startingFare: 0, timeCharge: 0,
        distanceCharge: 0, extras: 0, vat: 0, passThrough: 0, elapsed: .zero, distanceMetres: 0, vatExempt: false,
        logHead: ""
    )
}

extension FareReading {
    init(_ reading: MeterReading) {
        self.init(
            phase: Phase(reading.phase),
            currencyCode: reading.currency,
            rateId: reading.rateId,
            displayTotal: reading.displayTotal,
            total: reading.total,
            startingFare: reading.startingFare,
            timeCharge: reading.timeCharge,
            distanceCharge: reading.distanceCharge,
            extras: reading.extras,
            vat: reading.vat,
            passThrough: reading.passThrough,
            elapsed: .seconds(reading.chargedSeconds),
            distanceMetres: reading.distanceMetres,
            vatExempt: reading.vatExempt,
            logHead: reading.logHead
        )
    }
}

private extension FareReading.Phase {
    init(_ phase: MeterPhase) {
        switch phase {
        case .hired: self = .hired
        case .paused: self = .paused
        case .stopped: self = .stopped
        case .settled: self = .settled
        default: self = .idle
        }
    }
}
