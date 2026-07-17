import SwiftUI

struct AgentKey: View {
    let agent: Agent
    let isSelected: Bool
    let action: () -> Void
    @ScaledMetric(relativeTo: .caption) private var keyHeight = 114

    var body: some View {
        Button(action: action) {
            ZStack {
                keyBase
                keyCap
            }
            .frame(maxWidth: .infinity, minHeight: keyHeight)
            .contentShape(RoundedRectangle(cornerRadius: 21, style: .continuous))
        }
        .buttonStyle(TactileButtonStyle())
        .accessibilityLabel("\(agent.name), \(agent.status.label), \(agent.task)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var keyBase: some View {
        RoundedRectangle(cornerRadius: 21, style: .continuous)
            .fill(Color(red: 0.54, green: 0.58, blue: 0.64).opacity(0.43))
            .offset(y: 5)
            .shadow(color: agent.status.color.opacity(isSelected ? 0.46 : 0.12), radius: isSelected ? 12 : 5, y: 6)
    }

    private var keyCap: some View {
        VStack(spacing: 7) {
            HStack {
                StatusLED(status: agent.status, emphasized: isSelected)

                Spacer()

                Image(systemName: harnessIcon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 0)

            StatusLight(status: agent.status, isSelected: isSelected)

            Spacer(minLength: 0)

            Text(agent.name)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .tracking(-0.1)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(agent.status.label.uppercased())
                .font(.system(.caption2, design: .rounded, weight: .black))
                .tracking(0.32)
                .foregroundStyle(agent.status.color)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(11)
        .background {
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            .white,
                            isSelected
                                ? agent.status.color.opacity(0.16)
                                : Color(red: 0.95, green: 0.96, blue: 0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 21, style: .continuous)
                        .stroke(
                            isSelected ? agent.status.color.opacity(0.72) : .white.opacity(0.98),
                            lineWidth: isSelected ? 2 : 1
                        )
                }
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 21, style: .continuous)
                        .stroke(.white.opacity(0.92), lineWidth: 1)
                }
        }
        .overlay(alignment: .bottomTrailing) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(agent.status.color)
                    .padding(9)
                    .transition(.scale.combined(with: .opacity))
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
                    .fill(.white.opacity(0.82))
                    .frame(width: 2.5, height: 2.5)
                    .padding(1.2)
            }
            .shadow(color: status.color.opacity(emphasized ? 0.80 : 0.45), radius: emphasized ? 5 : 2)
    }
}

private struct StatusLight: View {
    let status: AgentStatus
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(status.color.opacity(isSelected ? 0.27 : 0.13))
                .frame(width: 49, height: 49)
                .blur(radius: isSelected ? 5 : 3)

            Circle()
                .stroke(status.color.opacity(isSelected ? 0.88 : 0.62), lineWidth: isSelected ? 2 : 1.5)
                .frame(width: 42, height: 42)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, Color(red: 0.90, green: 0.92, blue: 0.95)],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: 22
                    )
                )
                .frame(width: 34, height: 34)
                .shadow(color: .black.opacity(0.10), radius: 2, y: 1)

            Image(status.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)
                .accessibilityHidden(true)
        }
        .shadow(color: status.color.opacity(isSelected ? 0.35 : 0.13), radius: 8)
    }
}

struct EmptyKey: View {
    @ScaledMetric(relativeTo: .caption) private var keyHeight = 114

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .fill(Color.black.opacity(0.10))
                .offset(y: 5)

            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .fill(.white.opacity(0.38))
                .overlay {
                    RoundedRectangle(cornerRadius: 21, style: .continuous)
                        .stroke(.white.opacity(0.72), lineWidth: 1)
                }

            Image(systemName: "plus")
                .font(.system(size: 18, weight: .medium))
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
                    .fill(Color.black.opacity(0.12))
                    .offset(y: 4)

                VStack(spacing: 6) {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))

                    Text(title)
                        .font(.system(.caption2, design: .rounded, weight: .black))
                        .tracking(0.42)
                        .minimumScaleFactor(0.74)
                        .lineLimit(1)
                }
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .frame(minHeight: keyHeight)
                .background {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white, Color(red: 0.94, green: 0.95, blue: 0.97)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .stroke(.white.opacity(0.95), lineWidth: 1)
                        }
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
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .offset(y: configuration.isPressed ? 2 : 0)
            .animation(
                reduceMotion
                    ? .easeOut(duration: 0.08)
                    : .spring(response: 0.24, dampingFraction: 1),
                value: configuration.isPressed
            )
    }
}
