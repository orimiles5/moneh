import Foundation

/// Trip data on demand, as a file (spec 2018 §9.11). Amounts in agorot, distance in metres, times in ISO 8601.
enum TripExport {
    static let columns = [
        "invoice", "trip_id", "started_at", "stopped_at", "distance_m", "charged_s", "tariff", "source",
        "starting_fare", "time_charge", "distance_charge", "extras", "discount", "vat", "tolls", "rounding", "total",
        "agreed_price", "payment", "taxi", "licence", "dealer_name", "dealer_number", "driver_name", "driver_id",
    ]

    static func csv(_ trips: [FareReading]) -> String {
        let rows = trips.map { trip in
            let invoice = trip.invoice
            let fields: [String] = [
                invoice.map { String($0.number) } ?? "", trip.logHead,
                trip.startedAt.map(iso) ?? "", trip.stoppedAt.map(iso) ?? "",
                String(trip.distanceMetres), String(trip.elapsed.components.seconds), trip.rateId, trip.source,
                String(trip.startingFare), String(trip.timeCharge), String(trip.distanceCharge), String(trip.extras),
                String(trip.discount), String(trip.vat), String(trip.passThrough), String(trip.rounding),
                String(trip.total),
                String(trip.agreedPrice), trip.paymentMethod,
                invoice?.taxiNumber ?? "", invoice?.licenceNumber ?? "", invoice?.dealerName ?? "",
                invoice?.dealerNumber ?? "", invoice?.driverName ?? "", invoice?.driverId ?? "",
            ]
            return fields.map(escape).joined(separator: ",")
        }
        return ([columns.joined(separator: ",")] + rows).joined(separator: "\r\n") + "\r\n"
    }

    /// Writes the export to a temporary file for sharing.
    static func file(_ trips: [FareReading], now: Date = .now) throws -> URL {
        let day = now.formatted(.iso8601.year().month().day().dateSeparator(.omitted))
        let url = URL.temporaryDirectory.appending(path: "moneh-trips-\(day).csv")
        // A byte order mark so spreadsheet apps read the Hebrew names as UTF-8.
        try Data(("\u{FEFF}" + csv(trips)).utf8).write(to: url, options: .atomic)
        return url
    }

    private static func iso(_ date: Date) -> String {
        date.formatted(.iso8601)
    }

    private static func escape(_ field: String) -> String {
        guard field.contains(where: { ",\"\r\n".contains($0) }) else { return field }
        return "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
