import CoreLocation
import SwiftUI

/// One thing per screen: what Moneh is, the not-a-certified-meter notice, then location.
struct OnboardingView: View {
    enum Page: Int, CaseIterable {
        case welcome, notice, location
    }

    let onFinish: () -> Void
    @State private var page: Page
    @State private var locationSession: CLServiceSession?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(startingAt page: Page = .welcome, onFinish: @escaping () -> Void) {
        _page = State(initialValue: page)
        self.onFinish = onFinish
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.large) {
            Spacer()
            content
                .id(page)
                .transition(reduceMotion ? .opacity : .push(from: .trailing))
            Spacer()
            buttons
        }
        .padding(Spacing.xLarge)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .background(Palette.background.color)
        .sensoryFeedback(.selection, trigger: page)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Spacing.medium) {
            switch page {
            case .welcome:
                Text("onboarding.welcome.title").font(Typography.fare)
                Text("onboarding.welcome.body").font(Typography.headline)
            case .notice:
                Text("onboarding.notice.title").font(Typography.title)
                Text("notice.body").font(Typography.body)
            case .location:
                Image(systemName: "location.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Palette.accent.color)
                    .accessibilityHidden(true)
                Text("onboarding.location.title").font(Typography.title)
                Text("onboarding.location.body").font(Typography.body)
            }
        }
        .foregroundStyle(Palette.ink.color)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var buttons: some View {
        switch page {
        case .welcome:
            PillButton("onboarding.continue", style: .accent) { advance(to: .notice) }
        case .notice:
            PillButton("onboarding.notice.accept", style: .accent) { advance(to: .location) }
        case .location:
            VStack(spacing: Spacing.medium) {
                PillButton("onboarding.location.allow", style: .accent) {
                    // Holding a session with When-In-Use authorization shows the system prompt.
                    locationSession = CLServiceSession(authorization: .whenInUse)
                    onFinish()
                }
                PillButton("onboarding.location.later", style: .quiet, action: onFinish)
            }
        }
    }

    private func advance(to next: Page) {
        withAnimation(reduceMotion ? nil : Motion.standard) { page = next }
    }
}
