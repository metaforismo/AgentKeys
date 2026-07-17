import SwiftUI

struct ControlDeckView: View {
    @Bindable var store: AgentStore
    @State private var recorder = SpeechPromptRecorder()
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        NavigationStack {
            ZStack {
                DeckBackground()

                ScrollView {
                    VStack(spacing: 14) {
                        header
                        hardwareDeck
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 30)
                }
                .scrollIndicators(.hidden)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $store.isSettingsPresented) {
                ConnectorSettingsView(store: store)
            }
            .task { store.startPolling() }
            .onDisappear { store.stopPolling() }
            .onChange(of: recorder.transcript) { _, newValue in
                store.prompt = newValue
            }
            .sensoryFeedback(.selection, trigger: store.selectedAgentID)
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(.black)
                    .shadow(color: .black.opacity(0.22), radius: 8, y: 4)

                Image(systemName: "command")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text("AgentKeys")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .tracking(-0.4)

                HStack(spacing: 6) {
                    StatusLamp(color: connectionColor, size: 7)
                    Text(store.connectionState.label.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.15)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                store.isSettingsPresented = true
            } label: {
                RotaryControl()
            }
            .buttonStyle(TactileButtonStyle())
            .accessibilityLabel("Connector settings")
        }
        .padding(.horizontal, 2)
    }

    private var hardwareDeck: some View {
        HardwareChassis(
            accent: activeAccent,
            reduceTransparency: reduceTransparency
        ) {
            VStack(spacing: 14) {
                HardwareSectionHeader(
                    title: "Agent channels",
                    detail: "\(store.agents.count) agents",
                    systemImage: "dot.radiowaves.left.and.right"
                )

                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(store.agents) { agent in
                        AgentKey(agent: agent, isSelected: store.selectedAgentID == agent.id) {
                            store.selectedAgentID = agent.id
                        }
                    }

                    ForEach(0..<max(0, 6 - store.agents.count), id: \.self) { _ in
                        EmptyKey()
                    }
                }

                selectedAgentModule
                DeckDivider(accent: activeAccent)

                HardwareSectionHeader(
                    title: "Command keys",
                    detail: store.selectedAgent?.name ?? "No target",
                    systemImage: "switch.2"
                )

                HStack(spacing: 10) {
                    CommandKey(title: "Interrupt", systemImage: "bolt.fill", tint: .primary) {
                        Task { await store.perform(.interrupt) }
                    }
                    CommandKey(title: "Reject", systemImage: "xmark", tint: .red) {
                        Task { await store.perform(.reject) }
                    }
                    CommandKey(title: "Approve", systemImage: "checkmark", tint: .green) {
                        Task { await store.perform(.approve) }
                    }
                    CommandKey(title: "New", systemImage: "plus.bubble", tint: .blue) {
                        Task { await store.perform(.newChat) }
                    }
                }

                promptBay
                voiceKey

                HStack {
                    Text("AGENTKEYS // CONTROL DECK 01")
                    Spacer()
                    Text("BUILD WITH AGENTS")
                }
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .tracking(0.65)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)
            }
        }
    }

    private var selectedAgentModule: some View {
        HStack(spacing: 11) {
            if let status = store.selectedAgent?.status {
                ZStack {
                    Circle()
                        .fill(status.color.opacity(0.15))
                        .frame(width: 43, height: 43)
                        .blur(radius: 5)

                    Circle()
                        .fill(.white.opacity(0.74))
                        .overlay {
                            Circle().stroke(status.color.opacity(0.38), lineWidth: 1)
                        }

                    Image(status.assetName)
                        .resizable()
                        .scaledToFit()
                        .padding(6)
                        .accessibilityHidden(true)
                }
                .frame(width: 35, height: 35)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(store.selectedAgent?.name ?? "No agent selected")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .lineLimit(1)

                Text(store.selectedAgent?.task ?? "Connect a companion to see active work.")
                    .font(.system(.callout, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            if let status = store.selectedAgent?.status {
                StatusPill(status: status)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 11)
        .background {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(Color.black.opacity(0.035))
                .overlay {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .stroke(.white.opacity(0.76), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.07), radius: 2, y: -1)
        }
    }

    private var promptBay: some View {
        HStack(spacing: 8) {
            TextField("Prompt the selected agent", text: $store.prompt, axis: .vertical)
                .lineLimit(1...3)
                .font(.system(.body, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

            Button {
                let text = trimmedPrompt
                guard !text.isEmpty else { return }
                Task { await store.perform(.prompt, text: text) }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(.black, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.white.opacity(0.24), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.22), radius: 5, y: 3)
            }
            .buttonStyle(TactileButtonStyle())
            .disabled(trimmedPrompt.isEmpty)
            .opacity(trimmedPrompt.isEmpty ? 0.42 : 1)
            .accessibilityLabel("Send prompt")
            .padding(.trailing, 5)
        }
        .background {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .fill(Color.black.opacity(0.055))
                .overlay {
                    RoundedRectangle(cornerRadius: 19, style: .continuous)
                        .stroke(.white.opacity(0.74), lineWidth: 1)
                }
        }
    }

    private var voiceKey: some View {
        Button {
            Task {
                if recorder.isRecording {
                    recorder.stop()
                } else {
                    await recorder.start()
                }
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.18))
                    .offset(y: 5)

                HStack(spacing: 10) {
                    Image(systemName: recorder.isRecording ? "waveform" : "mic.fill")
                        .symbolEffect(.variableColor.iterative, isActive: recorder.isRecording)

                    Text(recorder.isRecording ? "Listening… tap to stop" : "Push to talk")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                }
                .foregroundStyle(recorder.isRecording ? .pink : .blue)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white, Color(red: 0.90, green: 0.93, blue: 0.97)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(voiceColor.opacity(0.54), lineWidth: 1.25)
                        }
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(.white.opacity(0.94), lineWidth: 1)
                        }
                        .shadow(color: voiceColor.opacity(0.23), radius: 9, y: 5)
                }
            }
        }
        .buttonStyle(TactileButtonStyle())
        .accessibilityHint("Uses Apple speech recognition to fill the prompt field")
    }

    private var trimmedPrompt: String {
        store.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var voiceColor: Color {
        recorder.isRecording ? .pink : .blue
    }

    private var activeAccent: Color {
        store.selectedAgent?.status.color ?? .cyan
    }

    private var connectionColor: Color {
        switch store.connectionState {
        case .demo: .orange
        case .connecting: .blue
        case .connected: .green
        case .failed: .red
        }
    }
}

private struct DeckBackground: View {
    var body: some View {
        ZStack {
            Color(red: 0.935, green: 0.95, blue: 0.975)

            RadialGradient(
                colors: [.cyan.opacity(0.11), .clear],
                center: .topTrailing,
                startRadius: 15,
                endRadius: 340
            )

            RadialGradient(
                colors: [.blue.opacity(0.07), .clear],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 390
            )
        }
        .ignoresSafeArea()
    }
}

private struct HardwareChassis<Content: View>: View {
    let accent: Color
    let reduceTransparency: Bool
    @ViewBuilder let content: Content
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 31, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.cyan.opacity(0.34), .blue.opacity(0.22), accent.opacity(0.27)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blur(radius: 13)
                        .offset(y: 8)

                    RoundedRectangle(cornerRadius: 31, style: .continuous)
                        .fill(
                            reduceTransparency
                                ? AnyShapeStyle(Color.white.opacity(0.97))
                                : AnyShapeStyle(.ultraThinMaterial)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 31, style: .continuous)
                                .fill(Color.white.opacity(reduceTransparency ? 0 : 0.33))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 31, style: .continuous)
                                .stroke(
                                    colorSchemeContrast == .increased
                                        ? Color.primary.opacity(0.42)
                                        : Color.white.opacity(0.90),
                                    lineWidth: 1.2
                                )
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(Color.black.opacity(0.055), lineWidth: 1)
                                .padding(5)
                        }
                        .shadow(color: .black.opacity(0.12), radius: 17, y: 9)

                    chassisFasteners

                    VStack {
                        Spacer()
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.cyan.opacity(0.15), .cyan.opacity(0.85), accent.opacity(0.64), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 3)
                            .blur(radius: 1.4)
                            .padding(.horizontal, 32)
                            .padding(.bottom, 3)
                    }
                }
            }
    }

    private var chassisFasteners: some View {
        VStack {
            HStack {
                DeckFastener()
                Spacer()
                DeckFastener()
            }
            Spacer()
            HStack {
                DeckFastener()
                Spacer()
                DeckFastener()
            }
        }
        .padding(9)
        .allowsHitTesting(false)
    }
}

private struct HardwareSectionHeader: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)

            Text(title.uppercased())
                .font(.system(size: 10, weight: .black, design: .rounded))
                .tracking(1.2)

            Spacer()

            Text(detail)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 5)
    }
}

private struct DeckDivider: View {
    let accent: Color

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(.black.opacity(0.07))
                .frame(height: 1)

            StatusLamp(color: accent, size: 5)

            Rectangle()
                .fill(.white.opacity(0.78))
                .frame(height: 1)
        }
        .padding(.horizontal, 3)
    }
}

private struct DeckFastener: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.18, green: 0.19, blue: 0.21), .black],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Image(systemName: "hexagon.fill")
                .font(.system(size: 5))
                .foregroundStyle(.black.opacity(0.95))

            Capsule()
                .fill(.white.opacity(0.22))
                .frame(width: 5, height: 1)
                .rotationEffect(.degrees(-35))
        }
        .frame(width: 10, height: 10)
        .shadow(color: .white.opacity(0.8), radius: 1, x: -1, y: -1)
    }
}

private struct RotaryControl: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.17))
                .frame(width: 49, height: 49)
                .offset(y: 4)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [.white, Color(red: 0.76, green: 0.79, blue: 0.84)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Circle().stroke(.white, lineWidth: 1)
                }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(red: 0.25, green: 0.26, blue: 0.28), .black],
                        center: .topLeading,
                        startRadius: 2,
                        endRadius: 23
                    )
                )
                .frame(width: 33, height: 33)

            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.9))
        }
        .frame(width: 47, height: 47)
        .shadow(color: .black.opacity(0.16), radius: 7, y: 4)
    }
}

private struct StatusLamp: View {
    let color: Color
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(.white.opacity(0.8))
                    .frame(width: size * 0.34, height: size * 0.34)
                    .padding(size * 0.16)
            }
            .shadow(color: color.opacity(0.76), radius: size * 0.65)
    }
}

private struct StatusPill: View {
    let status: AgentStatus

    var body: some View {
        HStack(spacing: 5) {
            StatusLamp(color: status.color, size: 6)
            Text(status.label)
                .lineLimit(1)
        }
        .font(.system(size: 10, weight: .bold, design: .rounded))
        .foregroundStyle(status.color)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(status.color.opacity(0.10), in: Capsule())
    }
}

#Preview("Hardware control deck") {
    ControlDeckView(store: AgentStore())
        .preferredColorScheme(.light)
}
