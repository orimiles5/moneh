import LocalAuthentication
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
    @State private var shiftSheet: (shifts: [Shift], trips: [PastTrip])?
    @State private var shiftProblem: LocalizedStringKey?

    var body: some View {
        MeterScreen(
            reading: model.reading,
            currentRateId: model.currentRateId,
            locationProblem: model.locationProblem,
            shiftOpen: model.shift != nil,
            actions: MeterActions(
                start: { model.start(vatExempt: vatExempt) },
                startAtAgreedPrice: { enteringAgreedPrice = true },
                resume: model.resume,
                stop: { confirmingStop = true },
                settle: { model.settle(paymentMethod: $0) },
                showExtras: { showingExtras = true },
                showSettings: { showingSettings = true },
                showHistory: { pastTrips = TripStore.standard.archivedTrips() },
                openShift: openShift,
                showShift: { shiftSheet = (TripStore.standard.allShifts(), TripStore.standard.archivedTrips()) }
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
        .sheet(isPresented: Binding(get: { shiftSheet != nil }, set: {
            if !$0 {
                shiftSheet = nil
            }
        })) {
            ShiftView(
                shift: model.shift,
                shifts: shiftSheet?.shifts ?? [],
                trips: shiftSheet?.trips ?? [],
                onClose: model.closeShift
            )
        }
        .alert(shiftProblem ?? "", isPresented: Binding(get: { shiftProblem != nil }, set: {
            if !$0 {
                shiftProblem = nil
            }
        })) {
            Button("common.done") {}
        }
        .sheet(isPresented: $enteringAgreedPrice) {
            AgreedPriceSheet(currencyCode: model.reading.currencyCode) {
                model.start(vatExempt: vatExempt, agreedPrice: $0)
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(
                tariffId: model.tariffId,
                tariffSources: model.tariffSources,
                report: MeterReportView(
                    tariffId: model.tariffId,
                    rates: model.rateReport,
                    extras: model.extras,
                    seal: TripStore.standard.sealLog()
                )
            )
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

    /// Spec 2018 §9.7: the driver is identified when the shift opens. Face ID or the device passcode stands in for the
    /// card.
    private func openShift() {
        guard IssuerProfile.load().isComplete else {
            shiftProblem = "shift.needsProfile"
            return
        }
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) else {
            shiftProblem = "shift.needsPasscode"
            return
        }
        Task {
            if await (try? context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: String(localized: "shift.identify")
            )) == true {
                model.openShift()
            }
        }
    }
}
