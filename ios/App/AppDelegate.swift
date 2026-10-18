import UIKit

/// Routes a CarPlay connection to its scene delegate when the CarPlay build flag is on; otherwise SwiftUI handles all
/// scenes.
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _: UIApplication,
        configurationForConnecting session: UISceneSession,
        options _: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: session.role)
        #if CARPLAY
            if session.role == .carTemplateApplication {
                configuration.delegateClass = CarPlaySceneDelegate.self
            }
        #endif
        return configuration
    }
}
