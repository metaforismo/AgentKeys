import SwiftUI

struct AgentKey: View {
    let agent: Agent
    let isSelected: Bool
    let action: () -> Void
    @ScaledMetric(relativeTo: .caption) private var keyHeight = 102

    var body: some View {
        Button(action: action) {
            ZStack {
                keyBase
                keyCap
            }
            .frame(maxWidth: .infinity, minHeight: keyHeight)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(TactileButtonStyle())
        .accessibilityLabel("\(agent.name), \(agent.status.label), \(agent.task)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var keyBase: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(Color(red: 0.64, green: 0.67, blue: 0.71).opacity(0.42))
            .offset(y: 4)
            .shadow(color: .black.opacity(0.10), radius: 5, y: 5)
    }

    private var keyCap: some View {
        VStack(spacing: 5) {
            HStack {
                StatusLED(status: agent.status, emphasized: isSelected)

                Spacer()

                Image(systemName: harnessIcon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }

            StatusLight(status: agent.status, isSelected: isSelected)

            Text(agent.name)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .tracking(-0.1)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Text(agent.status.label.uppercased())
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(0.65)
                .foregroundStyle(agent.status.color)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(white: 0.995),
                            isSelected
                                ? agent.status.color.opacity(0.09)
                                : Color(red: 0.945, green: 0.953, blue: 0.965)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            isSelected ? agent.status.color.opacity(0.72) : .white.opacity(0.90),
                            lineWidth: isSelected ? 1.5 : 1
                        )
                }
                .overlay(alignment: .top) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.72), lineWidth: 1)
                }
        }
        .overlay(alignment: .bottomTrailing) {
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(agent.status.color)
                    .padding(7)
                    .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private var harnessIcon: String {
        agent.provider.systemImage
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
                .frame(width: 42, height: 42)
                .blur(radius: isSelected ? 4 : 2)

            Circle()
                .stroke(status.color.opacity(isSelected ? 0.88 : 0.62), lineWidth: isSelected ? 2 : 1.5)
                .frame(width: 37, height: 37)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white, Color(red: 0.90, green: 0.92, blue: 0.95)],
                        center: .topLeading,
                        startRadius: 1,
                        endRadius: 22
                    )
                )
                .frame(width: 29, height: 29)
                .shadow(color: .black.opacity(0.10), radius: 2, y: 1)

            Image(status.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 23, height: 23)
                .accessibilityHidden(true)
        }
        .shadow(color: status.color.opacity(isSelected ? 0.28 : 0.10), radius: 6)
    }
}

struct EmptyKey: View {
    @ScaledMetric(relativeTo: .caption) private var keyHeight = 102

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.10))
                .offset(y: 5)

            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.26))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.58), lineWidth: 1)
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
    @ScaledMetric(relativeTo: .caption2) private var keyHeight = 56

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.black.opacity(0.11))
                    .offset(y: 3)

                VStack(spacing: 5) {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))

                    Text(title)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .tracking(0.2)
                        .minimumScaleFactor(0.74)
                        .lineLimit(1)
                }
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity)
                .frame(minHeight: keyHeight)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white, Color(red: 0.94, green: 0.95, blue: 0.97)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(.white.opacity(0.88), lineWidth: 1)
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
