import SwiftUI

/// Gates first-launch onboarding versus the main app shell.
struct RootView: View {
    @StateObject private var onboarding = OnboardingController()

    var body: some View {
        Group {
            if onboarding.needsOnboarding {
                OnboardingView(controller: onboarding)
            } else {
                ContentView(session: onboarding.sessionPreferences)
            }
        }
    }
}
