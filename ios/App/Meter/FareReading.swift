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
    var discount: Int64
    var agreedPrice: Int64
    var vat: Int64
    var passThrough: Int64
    var rounding: Int64
    var elapsed: Duration
    var distanceMetres: Int64
    var vatExempt: Bool
    var vatBasisPoints: Int32
    var startedAt: Date?
    var stoppedAt: Date?
    var invoice: Invoice?
    var paymentMethod: String
    var source: String
    var shared: Bool
    var logHead: String

    struct Invoice: Equatable {
        var number: Int64
        var taxiNumber: String
        var licenceNumber: String
        var dealerName: String
        var dealerNumber: String
        var driverName: String
        var driverId: String
    }

    static let idle = FareReading(
        phase: .idle, currencyCode: "ILS", rateId: "A", displayTotal: 0, displayFare: 0, displayExtras: 0, total: 0,
        startingFare: 0, timeCharge: 0,
        distanceCharge: 0, extras: 0, discount: 0, agreedPrice: 0, vat: 0, passThrough: 0, rounding: 0, elapsed: .zero,
        distanceMetres: 0,
        vatExempt: false,
        vatBasisPoints: 1800, startedAt: nil, stoppedAt: nil, invoice: nil,
        paymentMethod: "", source: "", shared: false, logHead: ""
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
            discount: reading.discount,
            agreedPrice: reading.agreedPrice,
            vat: reading.vat,
            passThrough: reading.passThrough,
            rounding: reading.rounding,
            elapsed: .seconds(reading.chargedSeconds),
            distanceMetres: reading.distanceMetres,
            vatExempt: reading.vatExempt,
            vatBasisPoints: reading.vatBasisPoints,
            startedAt: Date(epochMs: reading.startedAtMs),
            stoppedAt: Date(epochMs: reading.stoppedAtMs),
            invoice: reading.invoice.map {
                Invoice(
                    number: $0.number,
                    taxiNumber: $0.taxiNumber,
                    licenceNumber: $0.licenceNumber,
                    dealerName: $0.dealerName,
                    dealerNumber: $0.dealerNumber,
                    driverName: $0.driverName,
                    driverId: $0.driverId
                )
            },
            paymentMethod: reading.paymentMethod,
            source: reading.source,
            shared: reading.shared,
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
