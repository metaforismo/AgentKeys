import SwiftUI

struct AppOnboardingView: View {
    var onGetStarted: () -> Void = {}
    var onConnect: () -> Void = {}

    @State private var selectedPage = 0

    private let pages = OnboardingPage.all

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedPage) {
                ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                    OnboardingPageView(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))
            .animation(.snappy(duration: 0.34), value: selectedPage)
            .accessibilityLabel("Introduction")

            VStack(spacing: 12) {
                Button("Get Started", action: onGetStarted)
                    .buttonStyle(OnboardingPrimaryButtonStyle())
                    .accessibilityIdentifier("onboarding-get-started")
                    .accessibilityHint("Opens the interactive AgentKeys demo")

                Button("Connect a Mac", action: onConnect)
                    .buttonStyle(OnboardingSecondaryButtonStyle())
                    .accessibilityIdentifier("onboarding-connect-mac")
                    .accessibilityHint("Opens the connector setup")
            }
            .padding(.horizontal, 24)
            .padding(.top, 18)
            .padding(.bottom, 12)
            .background(Color.white)
        }
        .background(Color.white.ignoresSafeArea())
        .preferredColorScheme(.light)
    }
}

private struct OnboardingPage: Identifiable {
    let id: String
    let imageName: String
    let title: String
    let subtitle: String

    static let all = [
        OnboardingPage(
            id: "monitor",
            imageName: "OnboardingMonitor",
            title: "See every agent",
            subtitle: "Follow thinking, approvals and errors.\nKnow what needs you at a glance."
        ),
        OnboardingPage(
            id: "control",
            imageName: "OnboardingControl",
            title: "Stay in control",
            subtitle: "Approve, redirect and dictate prompts.\nKeep frequent actions within reach."
        ),
        OnboardingPage(
            id: "providers",
            imageName: "OnboardingProvider",
            title: "Choose your agent",
            subtitle: "Switch between Codex and Claude Code.\nControls adapt to every session."
        )
    ]
}

private struct OnboardingPageView: View {
    let page: OnboardingPage

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 18)

            Image(page.imageName)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 320, maxHeight: 350)
                .accessibilityHidden(true)

            Spacer(minLength: 4)

            Text(page.title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .tracking(-0.7)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 20)

            Text(page.subtitle)
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .lineLimit(2, reservesSpace: true)
                .frame(maxWidth: 340)
                .padding(.horizontal, 24)
                .padding(.top, 12)

            Spacer(minLength: 42)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct OnboardingPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(.black, in: Capsule(style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.86 : 1)
            .animation(.smooth(duration: 0.16), value: configuration.isPressed)
    }
}

private struct OnboardingSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.headline, design: .rounded, weight: .semibold))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color.black.opacity(configuration.isPressed ? 0.11 : 0.065), in: Capsule(style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.smooth(duration: 0.16), value: configuration.isPressed)
    }
}

#Preview {
    AppOnboardingView()
}
