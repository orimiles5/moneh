import CoreLocation

/// Streams location fixes while a trip is active, including in the background.
/// On iOS 18 a background activity session keeps updates flowing with When-In-Use authorization alone.
@MainActor
final class LocationFeed {
    enum Problem {
        case denied
        case servicesOff
    }

    private var serviceSession: CLServiceSession?
    private var backgroundSession: CLBackgroundActivitySession?
    private var task: Task<Void, Never>?

    var isRunning: Bool {
        task != nil
    }

    func start(onFix: @escaping @MainActor (CLLocation) -> Void, onProblem: @escaping @MainActor (Problem?) -> Void) {
        guard task == nil else { return }
        serviceSession = CLServiceSession(authorization: .whenInUse)
        backgroundSession = CLBackgroundActivitySession()
        task = Task {
            do {
                for try await update in CLLocationUpdate.liveUpdates(.automotiveNavigation) {
                    if update.authorizationDenied || update.authorizationRestricted {
                        onProblem(.denied)
                    } else if update.authorizationDeniedGlobally {
                        onProblem(.servicesOff)
                    } else {
                        onProblem(nil)
                    }
                    if let location = update.location {
                        onFix(location)
                    }
                }
            } catch {
                onProblem(.denied)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
        backgroundSession?.invalidate()
        backgroundSession = nil
        serviceSession?.invalidate()
        serviceSession = nil
    }
}
