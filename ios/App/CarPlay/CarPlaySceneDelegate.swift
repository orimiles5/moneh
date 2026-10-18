#if CARPLAY
    import CarPlay
    import Observation

    /// The Driving Task scene: one information template that follows the meter. Compiled only when CARPLAY_ENABLED.
    @MainActor
    final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
        private var interfaceController: CPInterfaceController?
        private let template = CPInformationTemplate(title: "", layout: .twoColumn, items: [], actions: [])
        private var shown: CarPlayContent?

        func templateApplicationScene(
            _: CPTemplateApplicationScene,
            didConnect interfaceController: CPInterfaceController
        ) {
            self.interfaceController = interfaceController
            template.title = String(localized: "onboarding.welcome.title")
            interfaceController.setRootTemplate(template, animated: false, completion: nil)
            follow()
        }

        func templateApplicationScene(
            _: CPTemplateApplicationScene,
            didDisconnectInterfaceController _: CPInterfaceController
        ) {
            interfaceController = nil
        }

        /// Re-renders whenever the model's reading changes, for as long as CarPlay is connected.
        private func follow() {
            guard interfaceController != nil else { return }
            let model = MeterModel.shared
            withObservationTracking {
                render(CarPlayContent(reading: model.reading, currentRateId: model.currentRateId, locale: .current))
            } onChange: { [weak self] in
                Task { @MainActor in self?.follow() }
            }
        }

        private func render(_ content: CarPlayContent) {
            guard content != shown else { return }
            shown = content
            template.items = content.items.map { CPInformationItem(title: $0.title, detail: $0.detail) }
            template.actions = content.actions.map(button)
        }

        private func button(for action: CarPlayContent.Action) -> CPTextButton {
            let model = MeterModel.shared
            return switch action {
            case .pause:
                CPTextButton(title: String(localized: "meter.pause"), textStyle: .normal) { _ in model.pause() }
            case .resume:
                CPTextButton(title: String(localized: "meter.resume"), textStyle: .confirm) { _ in model.resume() }
            case .stop:
                CPTextButton(title: String(localized: "meter.stop"), textStyle: .cancel) { _ in model.stop() }
            }
        }
    }
#endif
