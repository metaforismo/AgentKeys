import SwiftUI

struct DeviceControlSurface: View {
    @Bindable var store: AgentStore
    @Bindable var recorder: SpeechPromptRecorder

    let onOpenControls: () -> Void
    let onOpenBranch: () -> Void
    let onOpenSettings: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    private var selectedAgent: Agent? { store.selectedAgent }
    private var accent: Color { selectedAgent?.status.color ?? .cyan }

    var body: some View {
        VStack(spacing: 12) {
            DeviceMasthead(
                connectionLabel: store.connectionState.label,
                connectionColor: connectionColor,
                onSettings: onOpenSettings
            )

            AcrylicDeviceShell(accent: accent) {
                VStack(spacing: 10) {
                    DeviceSilkscreen()

                    LazyVGrid(columns: columns, spacing: 9) {
                        ModeKnob(
                            value: selectedAgent?.mode.label ?? "—",
                            action: cycleMode
                        )

                        agentSlot(at: 0)
                        agentSlot(at: 1)

                        AdvancedDial(action: onOpenControls)

                        agentSlot(at: 2)
                        agentSlot(at: 3)
                        agentSlot(at: 4)
                        AddAgentCap(action: onOpenSettings)

                        DeviceCommandKey(
                            title: "Interrupt",
                            systemImage: "bolt.fill",
                            tint: .primary,
                            enabled: selectedAgent?.status == .thinking,
                            action: interrupt
                        )

                        DeviceCommandKey(
                            title: rejectLabel,
                            systemImage: "xmark",
                            tint: .red,
                            enabled: selectedAgent?.status == .needsInput,
                            action: reject
                        )

                        DeviceCommandKey(
                            title: approveLabel,
                            systemImage: "checkmark",
                            tint: .green,
                            enabled: selectedAgent?.status == .needsInput,
                            action: approve
                        )

                        DeviceCommandKey(
                            title: "New",
                            systemImage: "arrow.up.right",
                            tint: .primary,
                            enabled: selectedAgent != nil,
                            action: newChat
                        )
                    }

                    SelectedAgentDisplay(
                        agent: selectedAgent,
                        onBranch: onOpenBranch
                    )

                    PromptConsole(
                        text: $store.prompt,
                        isRecording: recorder.isRecording,
                        onSend: sendPrompt,
                        onVoice: toggleRecording
                    )

                    Text("AGENTKEYS  /  WIRELESS CONTROL UNIT  /  01")
                        .font(.system(size: 6, weight: .bold, design: .monospaced))
                        .tracking(0.7)
                        .foregroundStyle(.black.opacity(0.32))
                }
            }
        }
    }

    @ViewBuilder
    private func agentSlot(at index: Int) -> some View {
        if store.agents.indices.contains(index) {
            let agent = store.agents[index]
            AgentHardwareCap(
                agent: agent,
                isSelected: store.selectedAgentID == agent.id,
                action: { select(agent) }
            )
        } else {
            AddAgentCap(action: onOpenSettings)
        }
    }

    private var connectionColor: Color {
        switch store.connectionState {
        case .demo: .orange
        case .connecting: .blue
        case .connected: .green
        case .failed: .red
        }
    }

    private var approveLabel: String {
        selectedAgent?.provider == .claudeCode ? "Allow" : "Approve"
    }

    private var rejectLabel: String {
        selectedAgent?.provider == .claudeCode ? "Deny" : "Reject"
    }

    private func select(_ agent: Agent) {
        store.selectedAgentID = agent.id
    }

    private func cycleMode() {
        Task { await store.cycleMode() }
    }

    private func interrupt() {
        Task { await store.perform(.interrupt) }
    }

    private func reject() {
        Task { await store.perform(.reject) }
    }

    private func approve() {
        Task { await store.perform(.approve) }
    }

    private func newChat() {
        Task { await store.perform(.newChat) }
    }

    private func sendPrompt() {
        let prompt = store.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        Task { await store.perform(.prompt, text: prompt) }
    }

    private func toggleRecording() {
        Task {
            if recorder.isRecording {
                recorder.stop()
            } else {
                await recorder.start()
            }
        }
    }
}

private struct DeviceMasthead: View {
    let connectionLabel: String
    let connectionColor: Color
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(.black)
                Image(systemName: "command")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 42, height: 42)
            .shadow(color: .black.opacity(0.18), radius: 7, y: 4)

            VStack(alignment: .leading, spacing: 2) {
                Text("AgentKeys")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .tracking(-0.5)
                HStack(spacing: 6) {
                    DeviceLED(color: connectionColor, size: 7)
                    Text(connectionLabel.uppercased())
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button(action: onSettings) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 39, height: 39)
                    .background(.white.opacity(0.76), in: Circle())
                    .overlay { Circle().stroke(.white, lineWidth: 1) }
                    .shadow(color: .black.opacity(0.11), radius: 5, y: 3)
            }
            .buttonStyle(TactileButtonStyle())
            .accessibilityLabel("Connector settings")
        }
        .padding(.horizontal, 4)
    }
}

private struct AcrylicDeviceShell<Content: View>: View {
    let accent: Color
    @ViewBuilder let content: Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        content
            .padding(.horizontal, 16)
            .padding(.top, 15)
            .padding(.bottom, 13)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 33, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.cyan.opacity(0.22), .mint.opacity(0.24), accent.opacity(0.20)],
                                startPoint: .bottomLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blur(radius: 9)
                        .offset(y: 7)

                    RoundedRectangle(cornerRadius: 31, style: .continuous)
                        .fill(
                            reduceTransparency
                                ? AnyShapeStyle(Color(red: 0.91, green: 0.93, blue: 0.94))
                                : AnyShapeStyle(.thinMaterial)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 31, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [.white.opacity(0.68), Color(red: 0.76, green: 0.82, blue: 0.84).opacity(0.24)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 31, style: .continuous)
                                .stroke(.white.opacity(0.96), lineWidth: 1.5)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 26, style: .continuous)
                                .stroke(.black.opacity(0.08), lineWidth: 1)
                                .padding(5)
                        }
                        .shadow(color: .black.opacity(0.15), radius: 17, y: 10)

                    DeviceFasteners()
                }
            }
    }
}

private struct DeviceSilkscreen: View {
    var body: some View {
        HStack {
            Text("AGENTKEYS  /  2026")
            Spacer()
            Image(systemName: "arrow.up")
            Spacer()
            Text("YOU CAN JUST BUILD THINGS")
        }
        .font(.system(size: 6, weight: .semibold, design: .monospaced))
        .tracking(0.45)
        .foregroundStyle(.black.opacity(0.46))
        .padding(.horizontal, 8)
    }
}

private struct DeviceFasteners: View {
    var body: some View {
        VStack {
            HStack { DeviceScrew(); Spacer(); DeviceScrew() }
            Spacer()
            HStack { DeviceScrew(); Spacer(); DeviceScrew() }
        }
        .padding(9)
        .allowsHitTesting(false)
    }
}

private struct DeviceScrew: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [Color(white: 0.26), .black], startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: "hexagon.fill")
                .font(.system(size: 5))
                .foregroundStyle(.black)
            Capsule()
                .fill(.white.opacity(0.28))
                .frame(width: 5, height: 1)
                .rotationEffect(.degrees(-35))
        }
        .frame(width: 11, height: 11)
        .shadow(color: .white.opacity(0.8), radius: 1, x: -1, y: -1)
    }
}

private struct ModeKnob: View {
    let value: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                ZStack {
                    Circle()
                        .fill(Color.black.opacity(0.16))
                        .frame(width: 58, height: 58)
                        .offset(y: 4)
                    Circle()
                        .fill(LinearGradient(colors: [.white, Color(white: 0.72)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 58, height: 58)
                        .overlay { Circle().stroke(.white, lineWidth: 1) }
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(LinearGradient(colors: [Color(white: 0.98), Color(white: 0.58)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 14, height: 43)
                        .offset(y: -7)
                        .shadow(color: .black.opacity(0.18), radius: 2, y: 2)
                }
                Text(value.uppercased())
                    .font(.system(size: 6, weight: .black, design: .monospaced))
                    .tracking(0.4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .frame(maxWidth: .infinity, minHeight: 84)
        }
        .buttonStyle(TactileButtonStyle())
        .accessibilityLabel("Mode, \(value)")
    }
}

private struct AdvancedDial: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(.black.opacity(0.20))
                        .frame(width: 58, height: 58)
                        .offset(y: 4)
                    Circle()
                        .fill(RadialGradient(colors: [Color(white: 0.24), .black], center: .topLeading, startRadius: 1, endRadius: 31))
                        .frame(width: 58, height: 58)
                    ForEach(0..<8, id: \.self) { index in
                        Capsule()
                            .fill(.white.opacity(0.25))
                            .frame(width: 2, height: 8)
                            .offset(y: -22)
                            .rotationEffect(.degrees(Double(index) * 45))
                    }
                    Image(systemName: "dial.medium")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.72))
                }
                Text("CONTROL")
                    .font(.system(size: 6, weight: .black, design: .monospaced))
                    .tracking(0.45)
            }
            .frame(maxWidth: .infinity, minHeight: 84)
        }
        .buttonStyle(TactileButtonStyle())
        .accessibilityLabel("Agent controls")
    }
}

private struct AgentHardwareCap: View {
    let agent: Agent
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(Color(white: 0.42).opacity(0.26))
                    .offset(y: 5)

                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(agent.status.color.opacity(isSelected ? 0.28 : 0.17))
                    .blur(radius: 7)

                VStack(spacing: 4) {
                    HStack {
                        DeviceLED(color: agent.status.color, size: 6)
                        Spacer()
                        Image(systemName: agent.provider.systemImage)
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(.black.opacity(0.30))
                    }

                    ZStack {
                        Circle()
                            .fill(agent.status.color.opacity(0.19))
                            .frame(width: 36, height: 36)
                            .blur(radius: 3)
                        Circle()
                            .fill(.white.opacity(0.74))
                            .frame(width: 31, height: 31)
                            .overlay { Circle().stroke(agent.status.color.opacity(0.60), lineWidth: 1.5) }
                        Image(agent.status.assetName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 23, height: 23)
                    }

                    Text(agent.name)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(agent.status.label.uppercased())
                        .font(.system(size: 5.5, weight: .black, design: .monospaced))
                        .tracking(0.4)
                        .foregroundStyle(agent.status.color)
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.76), agent.status.color.opacity(isSelected ? 0.24 : 0.11)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .stroke(isSelected ? agent.status.color.opacity(0.82) : .white.opacity(0.92), lineWidth: isSelected ? 1.5 : 1)
                        }
                        .overlay(alignment: .top) {
                            RoundedRectangle(cornerRadius: 17, style: .continuous)
                                .stroke(.white.opacity(0.82), lineWidth: 1)
                        }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 84)
        }
        .buttonStyle(TactileButtonStyle())
        .shadow(color: agent.status.color.opacity(isSelected ? 0.32 : 0.12), radius: isSelected ? 7 : 3, y: 3)
        .accessibilityLabel("\(agent.name), \(agent.status.label), \(agent.task)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct AddAgentCap: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(.black.opacity(0.12))
                    .offset(y: 5)
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(.white.opacity(0.30))
                    .overlay { RoundedRectangle(cornerRadius: 17).stroke(.white.opacity(0.65), lineWidth: 1) }
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .light))
                    .foregroundStyle(.black.opacity(0.28))
            }
            .frame(maxWidth: .infinity, minHeight: 84)
        }
        .buttonStyle(TactileButtonStyle())
        .accessibilityLabel("Add or connect an agent")
    }
}

private struct DeviceCommandKey: View {
    let title: String
    let systemImage: String
    let tint: Color
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(.black.opacity(0.16))
                    .offset(y: 5)
                VStack(spacing: 5) {
                    Image(systemName: systemImage)
                        .font(.system(size: 17, weight: .medium))
                    Text(title)
                        .font(.system(size: 7, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .foregroundStyle(tint)
                .frame(maxWidth: .infinity, minHeight: 61)
                .background {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(LinearGradient(colors: [.white, Color(white: 0.90)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay { RoundedRectangle(cornerRadius: 15).stroke(.white, lineWidth: 1) }
                }
            }
        }
        .buttonStyle(TactileButtonStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.40)
        .accessibilityLabel(title)
    }
}

private struct SelectedAgentDisplay: View {
    let agent: Agent?
    let onBranch: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if let agent {
                DeviceLED(color: agent.status.color, size: 9)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(agent.name)
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("\(agent.provider.shortLabel) · \(agent.model.uppercased()) · \(agent.speed.label.uppercased()) · \(agent.effort.label.uppercased())")
                            .font(.system(size: 6, weight: .black, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.40))
                            .lineLimit(1)
                    }
                    Text(agent.task)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.60))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                Button(action: onBranch) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.74))
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.08), in: Circle())
                }
                .disabled(!agent.capabilities.supportsBranch)
                .opacity(agent.capabilities.supportsBranch ? 1 : 0.35)
                .accessibilityLabel("Branch or worktree")
            } else {
                Text("NO AGENT SELECTED")
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.56))
            }
        }
        .padding(.horizontal, 13)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LinearGradient(colors: [Color(white: 0.11), Color(white: 0.035)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay { RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.15), lineWidth: 1) }
                .shadow(color: .black.opacity(0.20), radius: 6, y: 4)
        }
    }
}

private struct PromptConsole: View {
    @Binding var text: String
    let isRecording: Bool
    let onSend: () -> Void
    let onVoice: () -> Void

    private var trimmedText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 7) {
                TextField("Prompt selected agent", text: $text)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .submitLabel(.send)
                    .onSubmit(onSend)

                Button(action: onSend) {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(.black, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(TactileButtonStyle())
                .disabled(trimmedText.isEmpty)
                .opacity(trimmedText.isEmpty ? 0.36 : 1)
                .accessibilityLabel("Send prompt")
            }
            .padding(.leading, 12)
            .padding(.trailing, 5)
            .frame(minHeight: 42)
            .background(.black.opacity(0.055), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay { RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.72), lineWidth: 1) }

            Button(action: onVoice) {
                ZStack {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(.black.opacity(0.18))
                        .offset(y: 5)
                    HStack(spacing: 9) {
                        Image(systemName: isRecording ? "waveform" : "mic.fill")
                            .symbolEffect(.variableColor.iterative, isActive: isRecording)
                        Text(isRecording ? "Listening…" : "Push to talk")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(isRecording ? Color.pink : Color.primary)
                    .frame(maxWidth: .infinity, minHeight: 53)
                    .background {
                        RoundedRectangle(cornerRadius: 17, style: .continuous)
                            .fill(LinearGradient(colors: [.white, Color(white: 0.90)], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .overlay { RoundedRectangle(cornerRadius: 17).stroke(.white, lineWidth: 1) }
                    }
                }
            }
            .buttonStyle(TactileButtonStyle())
            .accessibilityHint("Uses Apple speech recognition to fill the prompt")
        }
    }
}

private struct DeviceLED: View {
    let color: Color
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(.white.opacity(0.84))
                    .frame(width: size * 0.32, height: size * 0.32)
                    .padding(size * 0.15)
            }
            .shadow(color: color.opacity(0.78), radius: size * 0.60)
    }
}

#Preview("Virtual device") {
    DeviceControlSurface(
        store: AgentStore(),
        recorder: SpeechPromptRecorder(),
        onOpenControls: {},
        onOpenBranch: {},
        onOpenSettings: {}
    )
    .padding()
    .background(Color(red: 0.925, green: 0.935, blue: 0.95))
}
