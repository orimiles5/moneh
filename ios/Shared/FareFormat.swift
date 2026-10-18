import Foundation

enum FareFormat {
    // ponytail: assumes 2 minor-unit digits (ILS, USD, EUR); read the currency's exponent when adding one like JPY.
    static func string(minorUnits: Int64, currencyCode: String, locale: Locale) -> String {
        (Decimal(minorUnits) / 100).formatted(.currency(code: currencyCode).locale(locale))
    }
}
