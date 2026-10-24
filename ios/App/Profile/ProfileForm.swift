import SwiftUI

/// The details every invoice carries. Saved as typed; trips stopped without them get no invoice.
struct ProfileForm: View {
    @State private var profile = IssuerProfile.load()

    var body: some View {
        Form {
            Section {
                TextField("profile.taxiNumber", text: $profile.taxiNumber)
                    .keyboardType(.numberPad)
                TextField("profile.licenceNumber", text: $profile.licenceNumber)
            } header: {
                Text("profile.taxi")
            }
            Section {
                TextField("profile.driverName", text: $profile.driverName)
                    .textContentType(.name)
                TextField("profile.driverId", text: $profile.driverId)
                    .keyboardType(.numberPad)
                if !profile.driverId.isEmpty, !IsraeliID.isValid(profile.driverId) {
                    Label("profile.driverId.invalid", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Palette.danger.color)
                }
            } header: {
                Text("profile.driver")
            }
            Section {
                ForEach($profile.dealers) { $dealer in
                    VStack {
                        TextField("profile.dealerName", text: $dealer.name)
                        TextField("profile.dealerNumber", text: $dealer.number)
                            .keyboardType(.numberPad)
                    }
                }
                .onDelete { profile.dealers.remove(atOffsets: $0) }
                Button("profile.addDealer") { profile.dealers.append(IssuerProfile.Dealer()) }
                if profile.dealers.count > 1 {
                    Picker("profile.activeDealer", selection: $profile.activeDealer) {
                        ForEach(profile.dealers.indices, id: \.self) { index in
                            Text(profile.dealers[index].name.isEmpty ? "—" : profile.dealers[index].name).tag(index)
                        }
                    }
                }
            } header: {
                Text("profile.dealers")
            } footer: {
                Text(profile.isComplete ? "profile.complete" : "profile.incomplete")
            }
        }
        .font(Typography.body)
        .scrollContentBackground(.hidden)
        .background(Palette.background.color)
        .navigationTitle("profile.title")
        .onChange(of: profile) { _, new in
            var fixed = new
            fixed.activeDealer = min(new.activeDealer, max(new.dealers.count - 1, 0))
            fixed.save()
        }
    }
}
