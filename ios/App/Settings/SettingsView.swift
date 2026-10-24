import SwiftUI

struct SettingsView: View {
    let tariffId: String
    let tariffSources: [(title: String, url: URL)]
    var report: MeterReportView?

    @AppStorage("appearance") private var appearance = AppearancePreference.system
    @AppStorage("vatExempt") private var vatExempt = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink("profile.title") { ProfileForm() }
                    if let report {
                        NavigationLink("report.title") { report }
                    }
                }
                Section {
                    Toggle("settings.night", isOn: Binding(
                        get: { appearance == .night },
                        set: { appearance = $0 ? .night : .system }
                    ))
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        Button("settings.language") { openURL(url) }
                    }
                }
                Section {
                    Toggle("settings.eilat", isOn: $vatExempt)
                } footer: {
                    Text("settings.eilat.footer")
                }
                Section("settings.notice") {
                    Text("notice.body")
                }
                Section("settings.tariff \(tariffId)") {
                    ForEach(tariffSources, id: \.url) { source in
                        Link(source.title, destination: source.url)
                            .environment(\.layoutDirection, .rightToLeft) // The sources are Hebrew legal citations.
                    }
                }
            }
            .font(Typography.body)
            .tint(Palette.accent.color)
            .scrollContentBackground(.hidden)
            .background(Palette.background.color)
            .navigationTitle("settings.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                }
            }
        }
    }
}
