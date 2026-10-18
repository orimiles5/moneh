import SwiftUI

@main
struct MonehApp: App {
    @AppStorage("appearance") private var appearance = AppearancePreference.system
    @AppStorage("onboarded") private var onboarded = false
    @State private var model = MeterModel()

    var body: some Scene {
        WindowGroup {
            Group {
                if onboarded {
                    MeterView(model: model)
                } else {
                    OnboardingView { onboarded = true }
                }
            }
            .preferredColorScheme(appearance.colorScheme)
        }
    }
}
