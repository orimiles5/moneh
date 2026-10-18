import SwiftUI

@main
struct MonehApp: App {
    @AppStorage("appearance") private var appearance = AppearancePreference.system
    @State private var model = MeterModel()

    var body: some Scene {
        WindowGroup {
            MeterView(model: model)
                .preferredColorScheme(appearance.colorScheme)
        }
    }
}
