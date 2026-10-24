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
    let onRemove: (String) -> Void
    let onDiscountPercent: (Int32) -> Void
    let onDiscountAmount: (Int64) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var amounts: [String: Decimal] = [:]
    @State private var added = 0
    @State private var removed = 0
    @State private var discountIsPercent = true
    @State private var discount: Decimal?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(extras.filter { $0.passengerPrice != nil }) { extra in
                        HStack(spacing: Spacing.small) {
                            addButton(extra)
                            AddedCount(times: extra.count) { remove(extra.id) }
                        }
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
                            AddedCount(times: extra.count) { remove(extra.id) }
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
                Section {
                    Picker("discount.kind", selection: $discountIsPercent) {
                        Text("discount.percent").tag(true)
                        Text("discount.amount").tag(false)
                    }
                    .pickerStyle(.segmented)
                    HStack {
                        if discountIsPercent {
                            TextField("discount.percent", value: $discount, format: .number)
                                .keyboardType(.decimalPad)
                        } else {
                            TextField("discount.amount", value: $discount, format: .currency(code: currencyCode))
                                .keyboardType(.decimalPad)
                        }
                        Button("discount.apply", action: applyDiscount)
                            .font(Typography.label)
                            .buttonStyle(.borderedProminent)
                            .tint(Palette.accent.color)
                            .foregroundStyle(Palette.onAccent.color)
                            .disabled(!discountIsValid)
                    }
                    .font(Typography.body)
                    .frame(minHeight: minimumTouchTarget)
                } header: {
                    Text("discount.title")
                } footer: {
                    Text("discount.hint")
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
            .sensoryFeedback(.decrease, trigger: removed)
        }
    }

    private func addButton(_ extra: ExtraItem) -> some View {
        Button {
            onAdd(extra.id)
            added += 1
        } label: {
            HStack(spacing: Spacing.small) {
                Text(LocalizedStringKey("extra." + extra.id))
                    .font(Typography.body)
                    .foregroundStyle(Palette.ink.color)
                Spacer(minLength: Spacing.small)
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

    private func price(_ minorUnits: Int64) -> String {
        FareFormat.string(minorUnits: minorUnits, currencyCode: currencyCode, locale: locale)
    }

    private var discountIsValid: Bool {
        guard let discount, discount > 0 else { return false }
        return !discountIsPercent || discount <= 100
    }

    private func applyDiscount() {
        guard let discount, discountIsValid else { return }
        if discountIsPercent {
            onDiscountPercent(Int32(FareFormat.minorUnits(discount))) // percent x 100 = basis points
        } else {
            onDiscountAmount(FareFormat.minorUnits(discount))
        }
        self.discount = nil
        added += 1
    }

    private func remove(_ id: String) {
        onRemove(id)
        removed += 1
    }

    private func amountBinding(_ id: String) -> Binding<Decimal?> {
        Binding(get: { amounts[id] }, set: { amounts[id] = $0 })
    }

    private func addAmount(_ id: String) {
        guard let amount = amounts[id], amount > 0 else { return }
        onAddAmount(id, FareFormat.minorUnits(amount))
        amounts[id] = nil
        added += 1
    }
}

/// How many times an extra is on this trip, with a minus to take back a mistaken tap; hidden until added once.
private struct AddedCount: View {
    let times: Int
    let onRemove: () -> Void

    var body: some View {
        if times > 0 {
            HStack(spacing: Spacing.tiny) {
                Button(action: onRemove) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Palette.inkSecondary.color)
                        .frame(width: minimumTouchTarget / 1.5, height: minimumTouchTarget)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("extras.remove"))
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
