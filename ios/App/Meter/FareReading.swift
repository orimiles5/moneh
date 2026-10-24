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
    var displayFare: Int64
    var displayExtras: Int64
    var total: Int64
    var startingFare: Int64
    var timeCharge: Int64
    var distanceCharge: Int64
    var extras: Int64
    var vat: Int64
    var passThrough: Int64
    var rounding: Int64
    var elapsed: Duration
    var distanceMetres: Int64
    var vatExempt: Bool
    var vatBasisPoints: Int32
    var startedAt: Date?
    var stoppedAt: Date?
    var logHead: String

    static let idle = FareReading(
        phase: .idle, currencyCode: "ILS", rateId: "A", displayTotal: 0, displayFare: 0, displayExtras: 0, total: 0,
        startingFare: 0, timeCharge: 0,
        distanceCharge: 0, extras: 0, vat: 0, passThrough: 0, rounding: 0, elapsed: .zero, distanceMetres: 0,
        vatExempt: false,
        vatBasisPoints: 1800, startedAt: nil, stoppedAt: nil, logHead: ""
    )
}

extension FareReading {
    init(_ reading: MeterReading) {
        self.init(
            phase: Phase(reading.phase),
            currencyCode: reading.currency,
            rateId: reading.rateId,
            displayTotal: reading.displayTotal,
            displayFare: reading.displayFare,
            displayExtras: reading.displayExtras,
            total: reading.total,
            startingFare: reading.startingFare,
            timeCharge: reading.timeCharge,
            distanceCharge: reading.distanceCharge,
            extras: reading.extras,
            vat: reading.vat,
            passThrough: reading.passThrough,
            rounding: reading.rounding,
            elapsed: .seconds(reading.chargedSeconds),
            distanceMetres: reading.distanceMetres,
            vatExempt: reading.vatExempt,
            vatBasisPoints: reading.vatBasisPoints,
            startedAt: Date(epochMs: reading.startedAtMs),
            stoppedAt: Date(epochMs: reading.stoppedAtMs),
            logHead: reading.logHead
        )
    }
}

private extension Date {
    /// The core reports 0 for "not yet".
    init?(epochMs: Int64) {
        guard epochMs > 0 else { return nil }
        self.init(timeIntervalSince1970: TimeInterval(epochMs) / 1000)
    }
}

extension FareReading.Phase {
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
