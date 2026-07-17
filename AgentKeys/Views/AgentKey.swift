import SwiftUI

struct AgentKey: View {
    let agent: Agent
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Circle()
                        .fill(agent.status.color)
                        .frame(width: 9, height: 9)
                        .shadow(color: agent.status.color.opacity(0.8), radius: agent.status == .thinking ? 6 : 0)
                    Spacer()
                    Image(systemName: harnessIcon)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                Image(agent.status.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 42, height: 42)
                    .accessibilityHidden(true)

                Text(agent.name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .lineLimit(1)
                Text(agent.status.label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .white.opacity(0.78) : .secondary)
            }
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(13)
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
            .background(
                isSelected ? agent.status.color : Color.white,
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(isSelected ? 0.65 : 1), lineWidth: 1)
            }
            .shadow(color: (isSelected ? agent.status.color : .black).opacity(0.18), radius: 8, y: 5)
        }
        .buttonStyle(TactileButtonStyle())
        .accessibilityLabel("\(agent.name), \(agent.status.label), \(agent.task)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var harnessIcon: String {
        agent.harness.localizedCaseInsensitiveContains("codex") ? "chevron.left.forwardslash.chevron.right" : "sparkles"
    }
}

struct EmptyKey: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.white.opacity(0.45))
            .frame(minHeight: 116)
            .overlay {
                Image(systemName: "plus")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.tertiary)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white, lineWidth: 1)
            }
    }
}

struct CommandKey: View {
    let title: String
    let systemImage: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Image(systemName: systemImage)
                    .font(.system(size: 19, weight: .bold))
                Text(title)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .frame(height: 66)
            .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.11), radius: 5, y: 4)
        }
        .buttonStyle(TactileButtonStyle())
        .accessibilityLabel(title)
    }
}

struct TactileButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .offset(y: configuration.isPressed ? 2 : 0)
            .animation(.spring(response: 0.18, dampingFraction: 0.72), value: configuration.isPressed)
    }
}
