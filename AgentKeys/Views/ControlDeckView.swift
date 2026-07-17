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
                    VStack(spacing: 16) {
                        header
                        agentConsole
                        commandConsole
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
                    .shadow(color: .black.opacity(0.22), radius: 9, y: 5)

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
                    Circle()
                        .fill(connectionColor)
                        .frame(width: 7, height: 7)
                        .shadow(color: connectionColor.opacity(0.8), radius: 4)
                    Text(store.connectionState.label.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                store.isSettingsPresented = true
            } label: {
                DeckKnob()
            }
            .buttonStyle(TactileButtonStyle())
            .accessibilityLabel("Connector settings")
        }
        .padding(.horizontal, 2)
    }

    private var agentConsole: some View {
        DeckPanel(accent: activeAccent, reduceTransparency: reduceTransparency) {
            VStack(spacing: 14) {
                deckTitle(
                    eyebrow: "AGENT CHANNELS",
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

                selectedTask
            }
        }
    }

    private var selectedTask: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Text(store.selectedAgent?.name ?? "No agent selected")
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .lineLimit(1)

                Spacer(minLength: 8)

                if let status = store.selectedAgent?.status {
                    StatusPill(status: status)
                }
            }

            Text(store.selectedAgent?.task ?? "Connect a companion to see active work.")
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.black.opacity(0.035))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.8), lineWidth: 1)
                }
        }
    }

    private var commandConsole: some View {
        DeckPanel(accent: .cyan, reduceTransparency: reduceTransparency) {
            VStack(spacing: 14) {
                deckTitle(
                    eyebrow: "COMMAND DECK",
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

                promptComposer
                voiceKey
            }
        }
    }

    private var promptComposer: some View {
        HStack(spacing: 10) {
            TextField("Prompt the selected agent", text: $store.prompt, axis: .vertical)
                .lineLimit(1...3)
                .font(.system(.body, design: .rounded))
                .padding(.horizontal, 15)
                .padding(.vertical, 13)
                .background {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.white.opacity(0.84))
                        .shadow(color: .black.opacity(0.08), radius: 2, y: -1)
                }

            Button {
                let text = store.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                Task { await store.perform(.prompt, text: text) }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(.black, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(.white.opacity(0.28), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.25), radius: 5, y: 4)
            }
            .buttonStyle(TactileButtonStyle())
            .disabled(store.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(store.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)
            .accessibilityLabel("Send prompt")
        }
        .padding(5)
        .background(Color.black.opacity(0.055), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
            HStack(spacing: 10) {
                Image(systemName: recorder.isRecording ? "waveform" : "mic.fill")
                    .symbolEffect(.variableColor.iterative, isActive: recorder.isRecording)
                Text(recorder.isRecording ? "Listening… tap to stop" : "Push to talk")
                    .font(.system(.headline, design: .rounded, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(voiceGradient)
                    .overlay(alignment: .top) {
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .stroke(.white.opacity(0.38), lineWidth: 1)
                    }
                    .shadow(color: voiceGlow.opacity(0.34), radius: 10, y: 6)
            }
        }
        .buttonStyle(TactileButtonStyle())
        .accessibilityHint("Uses Apple speech recognition to fill the prompt field")
    }

    private func deckTitle(eyebrow: String, detail: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.secondary)

            Text(eyebrow)
                .font(.system(.caption2, design: .rounded, weight: .black))
                .tracking(1.3)

            Spacer()

            Text(detail)
                .font(.system(.caption2, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 5)
    }

    private var activeAccent: Color {
        store.selectedAgent?.status.color ?? .cyan
    }

    private var voiceGradient: LinearGradient {
        LinearGradient(
            colors: recorder.isRecording
                ? [Color(red: 0.98, green: 0.28, blue: 0.47), Color(red: 0.58, green: 0.29, blue: 0.96)]
                : [Color(red: 0.20, green: 0.42, blue: 1), Color(red: 0.19, green: 0.65, blue: 0.96)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var voiceGlow: Color {
        recorder.isRecording ? .pink : .blue
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
                colors: [.cyan.opacity(0.12), .clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 320
            )

            RadialGradient(
                colors: [.blue.opacity(0.09), .clear],
                center: .bottomLeading,
                startRadius: 10,
                endRadius: 360
            )
        }
        .ignoresSafeArea()
    }
}

private struct DeckPanel<Content: View>: View {
    let accent: Color
    let reduceTransparency: Bool
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 15)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(accent.opacity(0.16))
                        .blur(radius: 13)
                        .offset(y: 7)

                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(
                            reduceTransparency
                                ? AnyShapeStyle(Color.white.opacity(0.96))
                                : AnyShapeStyle(.ultraThinMaterial)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .fill(Color.white.opacity(reduceTransparency ? 0 : 0.34))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [.white, .white.opacity(0.35), accent.opacity(0.32)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.25
                                )
                        }
                        .shadow(color: .black.opacity(0.10), radius: 16, y: 9)

                    panelFasteners
                }
            }
    }

    private var panelFasteners: some View {
        VStack {
            HStack {
                CornerScrew()
                Spacer()
                CornerScrew()
            }
            Spacer()
            HStack {
                CornerScrew()
                Spacer()
                CornerScrew()
            }
        }
        .padding(9)
        .allowsHitTesting(false)
    }
}

private struct CornerScrew: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color(red: 0.57, green: 0.60, blue: 0.64)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Capsule()
                .fill(.black.opacity(0.48))
                .frame(width: 5, height: 1.25)
                .rotationEffect(.degrees(-35))
        }
        .frame(width: 9, height: 9)
        .shadow(color: .white.opacity(0.9), radius: 1, x: -1, y: -1)
    }
}

private struct DeckKnob: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.16))
                .frame(width: 48, height: 48)
                .offset(y: 3)

            Circle()
                .fill(
                    LinearGradient(
                        colors: [.white, Color(red: 0.84, green: 0.87, blue: 0.91)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    Circle().stroke(.white, lineWidth: 1)
                }

            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 17, weight: .semibold))
        }
        .frame(width: 46, height: 46)
        .shadow(color: .black.opacity(0.14), radius: 7, y: 4)
    }
}

private struct StatusPill: View {
    let status: AgentStatus

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)
                .shadow(color: status.color.opacity(0.75), radius: 3)
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

#Preview("Tactile control deck") {
    ControlDeckView(store: AgentStore())
        .preferredColorScheme(.light)
}
