import SwiftUI

struct AgentKey: View {
    let agent: Agent
    let isSelected: Bool
    let action: () -> Void
    @ScaledMetric(relativeTo: .caption) private var keyHeight = 111

    var body: some View {
        Button(action: action) {
            ZStack {
                keyBase
                keyCap
            }
            .frame(maxWidth: .infinity, minHeight: keyHeight)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(TactileButtonStyle())
        .accessibilityLabel("\(agent.name), \(agent.status.label), \(agent.task)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var keyBase: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color(red: 0.60, green: 0.64, blue: 0.70).opacity(0.42))
            .offset(y: 5)
            .shadow(color: agent.status.color.opacity(isSelected ? 0.52 : 0.16), radius: isSelected ? 12 : 5, y: 6)
    }

    private var keyCap: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                StatusLED(status: agent.status, emphasized: isSelected)

                Spacer()

                Image(systemName: harnessIcon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            HStack(alignment: .bottom, spacing: 7) {
                StatusLight(status: agent.status, isSelected: isSelected)

                Spacer(minLength: 0)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(agent.status.color)
                        .symbolRenderingMode(.hierarchical)
                }
            }

            Text(agent.name)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .tracking(-0.15)
                .lineLimit(1)

            Text(agent.status.label.uppercased())
                .font(.system(.caption2, design: .rounded, weight: .black))
                .tracking(0.35)
                .foregroundStyle(agent.status.color)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .padding(11)
        .foregroundStyle(.primary)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .white,
                            isSelected ? agent.status.color.opacity(0.17) : Color(red: 0.95, green: 0.96, blue: 0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            isSelected ? agent.status.color.opacity(0.62) : .white,
                            lineWidth: isSelected ? 1.5 : 1
                        )
                }
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.white.opacity(0.85), lineWidth: 1)
                        .blur(radius: 0.4)
                }
        }
    }

    private var harnessIcon: String {
        agent.harness.localizedCaseInsensitiveContains("codex")
            ? "chevron.left.forwardslash.chevron.right"
            : "sparkles"
    }
}

private struct StatusLED: View {
    let status: AgentStatus
    let emphasized: Bool

    var body: some View {
        Circle()
            .fill(status.color)
            .frame(width: 7, height: 7)
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(.white.opacity(0.8))
                    .frame(width: 2.5, height: 2.5)
                    .padding(1.2)
            }
            .shadow(color: status.color.opacity(emphasized ? 0.95 : 0.62), radius: emphasized ? 6 : 3)
    }
}

private struct StatusLight: View {
    let status: AgentStatus
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(status.color.opacity(isSelected ? 0.28 : 0.15))
                .frame(width: 43, height: 43)
                .blur(radius: 7)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, Color(red: 0.87, green: 0.89, blue: 0.92)],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: 25
                    )
                )
                .overlay {
                    Circle().stroke(status.color.opacity(0.62), lineWidth: 1.3)
                }
                .shadow(color: .black.opacity(0.13), radius: 3, y: 2)

            Image(status.assetName)
                .resizable()
                .scaledToFit()
                .padding(7)
                .accessibilityHidden(true)
        }
        .frame(width: 36, height: 36)
    }
}

struct EmptyKey: View {
    @ScaledMetric(relativeTo: .caption) private var keyHeight = 111

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.09))
                .offset(y: 5)

            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.white.opacity(0.42))
                .overlay {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.white.opacity(0.8), lineWidth: 1)
                }

            Image(systemName: "plus")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .frame(minHeight: keyHeight)
        .accessibilityHidden(true)
    }
}

struct CommandKey: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void
    @ScaledMetric(relativeTo: .caption2) private var keyHeight = 62

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(Color.black.opacity(0.16))
                    .offset(y: 5)

                VStack(spacing: 6) {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .bold))
                    Text(title.uppercased())
                        .font(.system(.caption2, design: .rounded, weight: .black))
                        .tracking(0.55)
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                }
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .frame(minHeight: keyHeight)
                .background {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white, Color(red: 0.91, green: 0.93, blue: 0.96)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .stroke(.white, lineWidth: 1)
                        }
                        .shadow(color: tint.opacity(0.10), radius: 5, y: 3)
                }
            }
        }
        .buttonStyle(TactileButtonStyle())
        .accessibilityLabel(title)
    }
}

struct TactileButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .offset(y: configuration.isPressed ? 3 : 0)
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.08)
                    : .spring(response: 0.22, dampingFraction: 0.82),
                value: configuration.isPressed
            )
    }
}
