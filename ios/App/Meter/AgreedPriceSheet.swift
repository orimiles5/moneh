import SwiftUI

/// Starts a trip at a price agreed with the passenger beforehand (spec 2018 §9.9).
struct AgreedPriceSheet: View {
    let currencyCode: String
    let onStart: (Int64) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var amount: Decimal?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("agreedPrice.amount", value: $amount, format: .currency(code: currencyCode))
                        .keyboardType(.decimalPad)
                        .font(Typography.headline)
                        .frame(minHeight: minimumTouchTarget)
                } footer: {
                    Text("agreedPrice.hint")
                }
                PillButton("meter.start", style: .accent) {
                    guard let amount, amount > 0 else { return }
                    onStart(FareFormat.minorUnits(amount))
                    dismiss()
                }
                .disabled((amount ?? 0) <= 0)
                .listRowBackground(Color.clear)
            }
            .navigationTitle("meter.agreedPrice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
            }
        }
    }
}
