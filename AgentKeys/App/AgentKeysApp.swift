import SwiftUI

@main
struct AgentKeysApp: App {
    @State private var store = AgentStore()
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    ControlDeckView(store: store)
                        .transition(.opacity)
                } else {
                    AppOnboardingView(
                        onGetStarted: {
                            store.useDemo()
                            completeOnboarding()
                        },
                        onConnect: {
                            store.isSettingsPresented = true
                            completeOnboarding()
                        }
                    )
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.22), value: hasCompletedOnboarding)
                .preferredColorScheme(.light)
        }
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
    }
}
