import MonehCore
import SwiftUI

/// The tariff data report (spec 2018 Annex B) and the electronic seal (§7.3, Annex C), viewable while the meter is
/// free.
struct MeterReportView: View {
    let tariffId: String
    let rates: [RateReport]
    let extras: [ExtraItem]
    let seal: [SealEntry]

    @Environment(\.locale) private var locale
    private let profile = IssuerProfile.load()
    private let printedAt = Date()

    var body: some View {
        List {
            Section {
                LabeledContent("report.maker", value: "Moneh \(Bundle.main.appVersion)")
                LabeledContent("shift.meterId", value: MeterIdentity.id)
                LabeledContent("profile.taxiNumber", value: profile.taxiNumber)
                LabeledContent("profile.licenceNumber", value: profile.licenceNumber)
                LabeledContent("report.tariffVersion", value: tariffId)
                LabeledContent("report.printedAt", value: printedAt.formatted(.dateTime.locale(locale)))
                LabeledContent("report.calibration", value: String(localized: "report.calibration.gps"))
            }
            ForEach(rates, id: \.rateId) { rate in
                Section(LocalizedStringKey("rate." + rate.rateId)) {
                    LabeledContent("report.startingFare", value: money(rate.startingFare))
                    LabeledContent("report.perMinute", value: money(rate.perMinute))
                    ForEach(Array(zip(rate.perKmFromKm, rate.perKm)), id: \.0) { fromKm, price in
                        LabeledContent("report.perKm \(fromKm.intValue)", value: money(price.int64Value))
                    }
                }
            }
            Section {
                ForEach(extras) { extra in
                    LabeledContent(LocalizedStringKey("extra." + extra.id)) {
                        Text(extra.passengerPrice.map(money) ?? String(localized: "report.enteredAmount"))
                    }
                }
            } header: {
                Text("extras.title")
            } footer: {
                Text("report.vatIncluded")
            }
            Section {
                ForEach(Array(seal.suffix(5).reversed().enumerated()), id: \.offset) { _, entry in
                    let when = entry.recordedAt.formatted(.dateTime.day().month().year().hour().minute().locale(locale))
                    LabeledContent(when) {
                        switch entry.kind {
                        case .tariff: Text("seal.tariff \(entry.value)")
                        case .licence: Text("seal.licence \(entry.value)")
                        }
                    }
                }
            } header: {
                Text("seal.title")
            } footer: {
                Text("seal.footer")
            }
        }
        .font(Typography.body)
        .scrollContentBackground(.hidden)
        .background(Palette.background.color)
        .navigationTitle("report.title")
    }

    private func money(_ minorUnits: Int64) -> String {
        FareFormat.string(minorUnits: minorUnits, currencyCode: "ILS", locale: locale)
    }
}

extension Bundle {
    var appVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "?"
    }
}
