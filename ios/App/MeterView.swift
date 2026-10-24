import SwiftUI

/// Connects the live model to the screen and the extras sheet.
struct MeterView: View {
    let model: MeterModel
    @AppStorage("vatExempt") private var vatExempt = false
    @State private var showingExtras = false
    @State private var showingSettings = false
    @State private var confirmingStop = false
    @State private var pastTrips: [PastTrip]?
    @State private var enteringAgreedPrice = false

    var body: some View {
        MeterScreen(
            reading: model.reading,
            currentRateId: model.currentRateId,
            locationProblem: model.locationProblem,
            actions: MeterActions(
                start: { model.start(vatExempt: vatExempt) },
                startAtAgreedPrice: { enteringAgreedPrice = true },
                resume: model.resume,
                stop: { confirmingStop = true },
                newTrip: model.settle,
                showExtras: { showingExtras = true },
                showSettings: { showingSettings = true },
                showHistory: { pastTrips = TripStore.standard.archivedTrips() }
            )
        )
        .confirmationDialog("meter.stop.confirm", isPresented: $confirmingStop, titleVisibility: .visible) {
            Button("meter.stop.end", role: .destructive, action: model.stop)
        } message: {
            Text("meter.stop.confirm.message")
        }
        .sheet(isPresented: Binding(get: { pastTrips != nil }, set: {
            if !$0 {
                pastTrips = nil
            }
        })) {
            HistoryView(trips: pastTrips ?? [])
        }
        .sheet(isPresented: $enteringAgreedPrice) {
            AgreedPriceSheet(currencyCode: model.reading.currencyCode) {
                model.start(vatExempt: vatExempt, agreedPrice: $0)
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(tariffId: model.tariffId, tariffSources: model.tariffSources)
        }
        .sheet(isPresented: $showingExtras) {
            ExtrasSheet(
                extras: model.extras,
                currencyCode: model.reading.currencyCode,
                onAdd: model.addExtra,
                onAddAmount: { model.addExtra($0, amountMinorUnits: $1) },
                onRemove: model.removeExtra,
                onDiscountPercent: { model.discount(percentBasisPoints: $0) },
                onDiscountAmount: { model.discount(amountMinorUnits: $0) }
            )
            .presentationDetents([.medium, .large])
        }
    }
}
