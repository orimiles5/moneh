import Foundation

/// The taxi, its licensed dealers and the driver: what a tax invoice names (spec 2018 Annex A, §9.12).
struct IssuerProfile: Codable, Equatable {
    struct Dealer: Codable, Equatable, Identifiable {
        var id = UUID()
        var name = ""
        var number = ""
    }

    var taxiNumber = ""
    var licenceNumber = ""
    var driverName = ""
    var driverId = ""
    /// A taxi may have several licensed dealers (at least three, §9.12); the driver picks the one for the shift.
    var dealers = [Dealer()]
    var activeDealer = 0

    var dealer: Dealer? {
        dealers.indices.contains(activeDealer) ? dealers[activeDealer] : nil
    }

    var isComplete: Bool {
        guard let dealer else { return false }
        return ![taxiNumber, licenceNumber, driverName, dealer.name, dealer.number].contains { $0.isBlank }
            && IsraeliID.isValid(driverId)
    }

    private static let key = "issuerProfile"

    static func load(from defaults: UserDefaults = .standard) -> IssuerProfile {
        defaults.data(forKey: key)
            .flatMap { try? JSONDecoder().decode(IssuerProfile.self, from: $0) } ?? IssuerProfile()
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(try? JSONEncoder().encode(self), forKey: Self.key)
    }
}

/// Israeli ID numbers (תעודת זהות): nine digits, the last a check digit.
enum IsraeliID {
    static func isValid(_ id: String) -> Bool {
        let digits = id.compactMap(\.wholeNumberValue)
        guard digits.count == id.count, (5 ... 9).contains(digits.count) else { return false }
        let padded = Array(repeating: 0, count: 9 - digits.count) + digits
        let sum = padded.enumerated().reduce(0) { sum, item in
            let product = item.element * (item.offset.isMultiple(of: 2) ? 1 : 2)
            return sum + product / 10 + product % 10
        }
        return sum.isMultiple(of: 10)
    }
}

// ponytail: UserDefaults counter; move into the trip store if invoices must survive an app reinstall.
/// Invoice numbers run on per device, never reused.
enum InvoiceSequence {
    private static let key = "lastInvoiceNumber"

    static func next(in defaults: UserDefaults = .standard) -> Int64 {
        let number = Int64(defaults.integer(forKey: key)) + 1
        defaults.set(Int(number), forKey: key)
        return number
    }
}

private extension String {
    var isBlank: Bool {
        trimmingCharacters(in: .whitespaces).isEmpty
    }
}
