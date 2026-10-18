import SwiftUI

@main
struct MonehApp: App {
    @AppStorage("appearance") private var appearance = AppearancePreference.system

    var body: some Scene {
        WindowGroup {
            MeterView()
                .preferredColorScheme(appearance.colorScheme)
        }
    }
}
