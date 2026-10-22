import SwiftUI

/// An extra as the sheet shows it: what the passenger pays (nil for an amount entered at the time) and how often it was
/// added.
struct ExtraItem: Identifiable, Equatable {
    let id: String
    let passengerPrice: Int64?
    let count: Int
}

/// Extras the driver adds by hand. Fixed-price extras add with one tap; others (tolls) take an amount.
struct ExtrasSheet: View {
    let extras: [ExtraItem]
    let currencyCode: String
    let onAdd: (String) -> Void
    let onAddAmount: (String, Int64) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var amounts: [String: Decimal] = [:]
    @State private var added = 0

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(extras.filter { $0.passengerPrice != nil }) { extra in
                        Button {
                            onAdd(extra.id)
                            added += 1
                        } label: {
                            HStack(spacing: Spacing.small) {
                                Text(LocalizedStringKey("extra." + extra.id))
                                    .font(Typography.body)
                                    .foregroundStyle(Palette.ink.color)
                                Spacer(minLength: Spacing.small)
                                CountBadge(times: extra.count)
                                Text(price(extra.passengerPrice ?? 0))
                                    .font(Typography.label)
                                    .foregroundStyle(Palette.inkSecondary.color)
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(Palette.accent.color)
                            }
                            .frame(minHeight: minimumTouchTarget)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PressableRowStyle())
                    }
                } footer: {
                    Text("extras.hint")
                }
                ForEach(extras.filter { $0.passengerPrice == nil }) { extra in
                    Section {
                        HStack {
                            TextField(
                                "extras.amount",
                                value: amountBinding(extra.id),
                                format: .currency(code: currencyCode)
                            )
                            .keyboardType(.decimalPad)
                            .font(Typography.body)
                            CountBadge(times: extra.count)
                            Button("extras.add") { addAmount(extra.id) }
                                .font(Typography.label)
                                .buttonStyle(.borderedProminent)
                                .tint(Palette.accent.color)
                                .foregroundStyle(Palette.onAccent.color)
                                .disabled((amounts[extra.id] ?? 0) <= 0)
                        }
                        .frame(minHeight: minimumTouchTarget)
                    } header: {
                        Text(LocalizedStringKey("extra." + extra.id))
                    } footer: {
                        Text("extras.amount.hint")
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

    private func price(_ minorUnits: Int64) -> String {
        FareFormat.string(minorUnits: minorUnits, currencyCode: currencyCode, locale: locale)
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

/// How many times an extra is on this trip; hidden until it is added once.
private struct CountBadge: View {
    let times: Int

    var body: some View {
        if times > 0 {
            Text("extras.times \(times)")
                .font(Typography.label)
                .foregroundStyle(Palette.onAccent.color)
                .padding(.horizontal, Spacing.small)
                .background(Palette.accent.color, in: Capsule())
                .contentTransition(.numericText())
                .animation(Motion.quick, value: times)
                .accessibilityLabel(Text("extras.count \(times)"))
        }
    }
}

/// Lights the row up while pressed, so a tap is visible as well as felt.
private struct PressableRowStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, Spacing.small)
            .background(
                Palette.accent.color.opacity(configuration.isPressed ? 0.25 : 0),
                in: RoundedRectangle(cornerRadius: Radius.chip)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Motion.quick, value: configuration.isPressed)
    }
}
