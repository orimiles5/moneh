import SwiftUI

/// Extras the driver adds by hand. Fixed-price extras add with one tap; others (tolls) take an amount.
struct ExtrasSheet: View {
    let fixedPriceExtras: [String]
    let enteredAmountExtras: [String]
    let currencyCode: String
    let onAdd: (String) -> Void
    let onAddAmount: (String, Int64) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amounts: [String: Decimal] = [:]
    @State private var added = 0

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(fixedPriceExtras, id: \.self) { id in
                        Button {
                            onAdd(id)
                            added += 1
                        } label: {
                            Label(LocalizedStringKey("extra." + id), systemImage: "plus.circle.fill")
                                .font(Typography.body)
                                .foregroundStyle(Palette.ink.color)
                                .frame(minHeight: minimumTouchTarget)
                        }
                    }
                }
                ForEach(enteredAmountExtras, id: \.self) { id in
                    Section(LocalizedStringKey("extra." + id)) {
                        HStack {
                            TextField("extras.amount", value: amountBinding(id), format: .currency(code: currencyCode))
                                .keyboardType(.decimalPad)
                                .font(Typography.body)
                            Button("extras.add") { addAmount(id) }
                                .font(Typography.label)
                                .disabled((amounts[id] ?? 0) <= 0)
                        }
                        .frame(minHeight: minimumTouchTarget)
                    }
                }
            }
            .navigationTitle("extras.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                }
            }
            .sensoryFeedback(.success, trigger: added)
        }
    }

    private func amountBinding(_ id: String) -> Binding<Decimal?> {
        Binding(get: { amounts[id] }, set: { amounts[id] = $0 })
    }

    private func addAmount(_ id: String) {
        guard let amount = amounts[id], amount > 0 else { return }
        // ponytail: two minor-unit digits, as in FareFormat.
        let minorUnits = NSDecimalNumber(decimal: amount * 100).rounding(accordingToBehavior: nil).int64Value
        onAddAmount(id, minorUnits)
        amounts[id] = nil
        added += 1
    }
}
