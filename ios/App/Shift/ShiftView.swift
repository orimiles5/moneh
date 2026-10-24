import MonehCore
import SwiftUI

/// Shift summary, cumulative totals and past shifts (spec 2018 §8.3). Shown only while the meter is free.
struct ShiftView: View {
    let shift: Shift?
    let shifts: [Shift]
    let trips: [PastTrip]
    let onClose: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var confirmingClose = false

    var body: some View {
        NavigationStack {
            List {
                if let shift {
                    ShiftSummary(shift: shift, totals: totals(for: shift))
                    Section {
                        Button("shift.close", role: .destructive) { confirmingClose = true }
                            .frame(minHeight: minimumTouchTarget)
                    }
                }
                Section("shift.cumulative") {
                    TotalsRows(totals: cumulative)
                    LabeledContent("shift.meterId", value: MeterIdentity.id)
                }
                let past = shifts.filter { $0.closedAt != nil }
                if !past.isEmpty {
                    Section("shift.past") {
                        ForEach(past) { closed in
                            NavigationLink {
                                List { ShiftSummary(shift: closed, totals: totals(for: closed)) }
                                    .scrollContentBackground(.hidden)
                                    .background(Palette.background.color)
                            } label: {
                                ShiftLabel(shift: closed, income: totals(for: closed).income)
                            }
                        }
                    }
                }
            }
            .font(Typography.body)
            .scrollContentBackground(.hidden)
            .background(Palette.background.color)
            .navigationTitle("shift.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                }
            }
            .confirmationDialog("shift.close.confirm", isPresented: $confirmingClose, titleVisibility: .visible) {
                Button("shift.close", role: .destructive) {
                    onClose()
                    dismiss()
                }
            }
        }
    }

    private func totals(for shift: Shift) -> ShiftTotals {
        let readings = trips.filter { $0.reading.map(shift.includes) ?? false }.compactMap(\.coreReading)
        return ShiftTotals.companion.of(trips: readings, drivenMetres: shift.drivenMetres)
    }

    private var cumulative: ShiftTotals {
        ShiftTotals.companion.of(
            trips: trips.compactMap(\.coreReading),
            drivenMetres: shifts.reduce(0) { $0 + $1.drivenMetres }
        )
    }
}

private struct ShiftSummary: View {
    let shift: Shift
    let totals: ShiftTotals

    @Environment(\.locale) private var locale

    var body: some View {
        Section {
            LabeledContent("profile.driverName", value: "\(shift.driverName) · \(shift.driverId)")
            LabeledContent("profile.dealers", value: "\(shift.dealerName) · \(shift.dealerNumber)")
            LabeledContent("profile.taxi", value: "\(shift.taxiNumber) · \(shift.licenceNumber)")
            LabeledContent("shift.opened", value: time(shift.openedAt))
            if let closed = shift.closedAt {
                LabeledContent("shift.closed", value: time(closed))
            }
            TotalsRows(totals: totals)
        } header: {
            Text(shift.closedAt == nil ? "shift.current" : "shift.summary")
        }
    }

    private func time(_ date: Date) -> String {
        date.formatted(.dateTime.day().month().year().hour().minute().locale(locale))
    }
}

private struct TotalsRows: View {
    let totals: ShiftTotals

    @Environment(\.locale) private var locale

    var body: some View {
        LabeledContent("shift.trips", value: totals.trips.formatted(.number.locale(locale)))
        LabeledContent("shift.cash", value: money(totals.cash))
        LabeledContent("shift.card", value: money(totals.card))
        LabeledContent("shift.income", value: money(totals.income))
        LabeledContent("shift.extras", value: money(totals.extras))
        LabeledContent("shift.driven", value: km(totals.drivenMetres))
        LabeledContent("shift.hired", value: km(totals.hiredMetres))
    }

    private func money(_ minorUnits: Int64) -> String {
        FareFormat.string(minorUnits: minorUnits, currencyCode: "ILS", locale: locale)
    }

    /// Whole kilometres, as the spec's counters show them.
    private func km(_ metres: Int64) -> String {
        Measurement(value: Double(metres / 1000), unit: UnitLength.kilometers)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided).locale(locale))
    }
}

private struct ShiftLabel: View {
    let shift: Shift
    let income: Int64

    @Environment(\.locale) private var locale

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(shift.openedAt.formatted(.dateTime.weekday().day().month().hour().minute().locale(locale)))
                Text(shift.driverName)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkSecondary.color)
            }
            Spacer()
            Text(FareFormat.string(minorUnits: income, currencyCode: "ILS", locale: locale))
                .monospacedDigit()
        }
    }
}

/// The meter's own number on reports (§8.3.2): one per install.
enum MeterIdentity {
    static var id: String {
        let key = "meterId"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let new = String(UUID().uuidString.prefix(8))
        UserDefaults.standard.set(new, forKey: key)
        return new
    }
}
