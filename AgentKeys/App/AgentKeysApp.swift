import SwiftUI

@main
struct AgentKeysApp: App {
    @State private var store = AgentStore()
    @State private var hasCompletedOnboarding: Bool

    init() {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-ui-testing") {
            _hasCompletedOnboarding = State(initialValue: arguments.contains("-ui-testing-onboarded"))
        } else {
            _hasCompletedOnboarding = State(initialValue: UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))
        }
#else
        _hasCompletedOnboarding = State(initialValue: UserDefaults.standard.bool(forKey: "hasCompletedOnboarding"))
#endif
    }

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
            .onOpenURL { url in
                guard let configuration = PairingLink.parse(url) else { return }
                store.apply(pairing: configuration)
                completeOnboarding()
            }
        }
    }

    private func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
}
