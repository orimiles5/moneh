import SwiftUI

/// Finished trips by day, newest first, each opening its receipt.
struct HistoryView: View {
    let trips: [PastTrip]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.calendar) private var calendar

    var body: some View {
        NavigationStack {
            Group {
                if trips.isEmpty {
                    ContentUnavailableView {
                        Label("history.empty", systemImage: "clock.arrow.circlepath")
                    } description: {
                        Text("history.empty.message")
                    }
                } else {
                    list
                }
            }
            .background(Palette.background.color)
            .navigationTitle("history.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                }
            }
        }
    }

    private var list: some View {
        List {
            ForEach(days, id: \.day) { day in
                Section {
                    ForEach(day.readings, id: \.logHead) { reading in
                        NavigationLink {
                            ReceiptDetail(reading: reading)
                        } label: {
                            TripRow(reading: reading)
                        }
                    }
                } header: {
                    HStack {
                        Text(day.day.formatted(.dateTime.weekday(.wide).day().month().locale(locale)))
                        Spacer()
                        Text(money(day.readings.reduce(0) { $0 + $1.total }, day.readings[0].currencyCode))
                            .monospacedDigit()
                    }
                    .font(Typography.label)
                }
            }
            if !damaged.isEmpty {
                Section("history.damaged") {
                    ForEach(damaged) { _ in
                        Label("history.damaged.row", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(Palette.danger.color)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private var days: [(day: Date, readings: [FareReading])] {
        let readings = trips.compactMap(\.reading)
        let grouped = Dictionary(grouping: readings) { calendar.startOfDay(for: $0.startedAt ?? .distantPast) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0] ?? []) }
    }

    private var damaged: [PastTrip] {
        trips.filter { $0.reading == nil }
    }

    private func money(_ minorUnits: Int64, _ currencyCode: String) -> String {
        FareFormat.string(minorUnits: minorUnits, currencyCode: currencyCode, locale: locale)
    }
}

private struct TripRow: View {
    let reading: FareReading

    @Environment(\.locale) private var locale

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: Spacing.tiny) {
                Text((reading.startedAt ?? .distantPast).formatted(.dateTime.hour().minute().locale(locale)))
                    .font(Typography.body)
                Text(details)
                    .font(Typography.caption)
                    .foregroundStyle(Palette.inkSecondary.color)
            }
            Spacer()
            Text(FareFormat.string(minorUnits: reading.total, currencyCode: reading.currencyCode, locale: locale))
                .font(Typography.label.monospacedDigit())
        }
        .foregroundStyle(Palette.ink.color)
        .frame(minHeight: minimumTouchTarget)
    }

    private var details: String {
        let distance = Measurement(value: Double(reading.distanceMetres) / 1000, unit: UnitLength.kilometers)
            .formatted(.measurement(
                width: .abbreviated,
                usage: .asProvided,
                numberFormatStyle: .number.precision(.fractionLength(1))
            )
            .locale(locale))
        let time = reading.elapsed.formatted(.units(allowed: [.hours, .minutes], width: .abbreviated).locale(locale))
        return distance + " · " + time
    }
}

private struct ReceiptDetail: View {
    let reading: FareReading

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.large) {
                ReceiptCard(reading: reading)
                ReceiptShareButton(reading: reading)
            }
            .padding(Spacing.large)
        }
        .background(Palette.background.color)
        .navigationTitle("receipt.title")
        .navigationBarTitleDisplayMode(.inline)
    }
}
