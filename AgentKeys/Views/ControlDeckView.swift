import SwiftUI

struct ControlDeckView: View {
    @Bindable var store: AgentStore
    @State private var recorder = SpeechPromptRecorder()

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 14), count: 3)

    var body: some View {
        NavigationStack {
            ZStack {
                Color(red: 0.95, green: 0.96, blue: 0.98).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 22) {
                        header
                        agentGrid
                        selectedTask
                        commandDeck
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
                }
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
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(.black)
                Image(systemName: "command")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text("AgentKeys")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                HStack(spacing: 6) {
                    Circle()
                        .fill(connectionColor)
                        .frame(width: 7, height: 7)
                    Text(store.connectionState.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                store.isSettingsPresented = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(.white, in: Circle())
                    .shadow(color: .black.opacity(0.10), radius: 7, y: 3)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Connector settings")
        }
        .padding(.top, 12)
    }

    private var agentGrid: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(store.agents) { agent in
                AgentKey(agent: agent, isSelected: store.selectedAgentID == agent.id) {
                    store.selectedAgentID = agent.id
                }
            }
            ForEach(0..<max(0, 6 - store.agents.count), id: \.self) { _ in
                EmptyKey()
            }
        }
    }

    private var selectedTask: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(store.selectedAgent?.name ?? "No agent selected")
                    .font(.subheadline.weight(.bold))
                Spacer()
                if let status = store.selectedAgent?.status {
                    Label(status.label, systemImage: "circle.fill")
                        .labelStyle(StatusLabelStyle(color: status.color))
                }
            }
            Text(store.selectedAgent?.task ?? "Connect a companion to see active work.")
                .font(.system(.body, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var commandDeck: some View {
        VStack(spacing: 14) {
            HStack(spacing: 12) {
                CommandKey(title: "Interrupt", systemImage: "bolt.fill", tint: .black) {
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

            HStack(spacing: 12) {
                TextField("Prompt the selected agent", text: $store.prompt, axis: .vertical)
                    .lineLimit(1...3)
                    .font(.system(.body, design: .rounded))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(.white, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

                Button {
                    let text = store.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    Task { await store.perform(.prompt, text: text) }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(.black, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                }
                .buttonStyle(TactileButtonStyle())
                .accessibilityLabel("Send prompt")
            }

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
                        .font(.system(.headline, design: .rounded))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    LinearGradient(
                        colors: recorder.isRecording ? [.pink, .purple] : [Color(red: 0.20, green: 0.42, blue: 1), Color(red: 0.26, green: 0.60, blue: 1)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                )
            }
            .buttonStyle(TactileButtonStyle())
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.85), lineWidth: 1)
        }
        .shadow(color: .blue.opacity(0.10), radius: 18, y: 8)
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

private struct StatusLabelStyle: LabelStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 5) {
            configuration.icon
                .font(.system(size: 7))
                .foregroundStyle(color)
            configuration.title
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }
}

