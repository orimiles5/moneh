import SwiftUI

/// Connects the live model to the screen and the extras sheet.
struct MeterView: View {
    let model: MeterModel
    @AppStorage("vatExempt") private var vatExempt = false
    @State private var showingExtras = false
    @State private var showingSettings = false
    @State private var confirmingStop = false

    var body: some View {
        MeterScreen(
            reading: model.reading,
            currentRateId: model.currentRateId,
            locationProblem: model.locationProblem,
            actions: MeterActions(
                start: { model.start(vatExempt: vatExempt) },
                pause: model.pause,
                resume: model.resume,
                stop: { confirmingStop = true },
                newTrip: model.settle,
                showExtras: { showingExtras = true },
                showSettings: { showingSettings = true }
            )
        )
        .confirmationDialog("meter.stop.confirm", isPresented: $confirmingStop, titleVisibility: .visible) {
            Button("meter.stop.end", role: .destructive, action: model.stop)
        } message: {
            Text("meter.stop.confirm.message")
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(tariffId: model.tariffId, tariffSources: model.tariffSources)
        }
        .sheet(isPresented: $showingExtras) {
            ExtrasSheet(
                extras: model.extras,
                currencyCode: model.reading.currencyCode,
                onAdd: model.addExtra,
                onAddAmount: { model.addExtra($0, amountMinorUnits: $1) }
            )
            .presentationDetents([.medium, .large])
        }
    }
}
