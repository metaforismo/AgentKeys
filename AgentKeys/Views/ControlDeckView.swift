import SwiftUI

struct ControlDeckView: View {
    @Bindable var store: AgentStore
    @State private var recorder = SpeechPromptRecorder()
    @State private var activeSheet: DeckSheet?
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
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .controls:
                    ProviderControlSheet(store: store)
                case .branch:
                    BranchControlSheet(store: store)
                case .settings:
                    ConnectorSettingsView(store: store)
                }
            }
            .task { store.startPolling() }
            .onAppear {
                if store.isSettingsPresented {
                    activeSheet = .settings
                    store.isSettingsPresented = false
                }
            }
            .onChange(of: store.isSettingsPresented) { _, shouldPresent in
                guard shouldPresent else { return }
                activeSheet = .settings
                store.isSettingsPresented = false
            }
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

            HStack(spacing: 8) {
                Button {
                    activeSheet = .controls
                } label: {
                    RotaryControl()
                }
                .buttonStyle(TactileButtonStyle())
                .accessibilityLabel("Agent mode and effort controls")

                Button {
                    activeSheet = .settings
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 34, height: 34)
                        .background(.white.opacity(0.72), in: Circle())
                        .overlay { Circle().stroke(.white, lineWidth: 1) }
                        .shadow(color: .black.opacity(0.10), radius: 4, y: 2)
                }
                .buttonStyle(TactileButtonStyle())
                .accessibilityLabel("Connector settings")
            }
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
                capabilityControls
                workflowConsole
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
                    CommandKey(title: rejectLabel, systemImage: "xmark", tint: .red) {
                        Task { await store.perform(.reject) }
                    }
                    CommandKey(title: approveLabel, systemImage: "checkmark", tint: .green) {
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
                HStack(spacing: 7) {
                    Text(store.selectedAgent?.name ?? "No agent selected")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                        .lineLimit(1)

                    if let provider = store.selectedAgent?.provider {
                        ProviderBadge(provider: provider, model: store.selectedAgent?.model)
                    }
                }

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

    private var capabilityControls: some View {
        HStack(spacing: 8) {
            MiniControlKey(
                eyebrow: "MODE",
                value: store.selectedAgent?.mode.label ?? "—",
                systemImage: "switch.2"
            ) {
                Task { await store.cycleMode() }
            }

            MiniControlKey(
                eyebrow: "SPEED",
                value: store.selectedAgent?.speed.label ?? "—",
                systemImage: store.selectedAgent?.speed == .fast ? "hare.fill" : "speedometer"
            ) {
                Task { await store.cycleSpeed() }
            }
            .opacity((store.selectedAgent?.capabilities.speeds.count ?? 0) > 1 ? 1 : 0.54)

            MiniControlKey(
                eyebrow: "EFFORT",
                value: store.selectedAgent?.effort.label ?? "—",
                systemImage: "dial.medium"
            ) {
                Task { await store.cycleEffort() }
            }

            MiniControlKey(
                eyebrow: "BRANCH",
                value: store.selectedAgent?.branch ?? "New",
                systemImage: "arrow.triangle.branch"
            ) {
                activeSheet = .branch
            }
            .opacity(store.selectedAgent?.capabilities.supportsBranch == true ? 1 : 0.54)
        }
    }

    private var workflowConsole: some View {
        VStack(spacing: 9) {
            HardwareSectionHeader(
                title: "Workflow joystick",
                detail: "Flick to run",
                systemImage: "dpad"
            )

            WorkflowPad(workflows: store.selectedAgent?.capabilities.workflows ?? []) { workflow in
                Task { await store.run(workflow) }
            }
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

    private var approveLabel: String {
        store.selectedAgent?.provider == .claudeCode ? "Allow" : "Approve"
    }

    private var rejectLabel: String {
        store.selectedAgent?.provider == .claudeCode ? "Deny" : "Reject"
    }
}

private enum DeckSheet: String, Identifiable {
    case controls
    case branch
    case settings

    var id: String { rawValue }
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

private struct ProviderBadge: View {
    let provider: AgentProvider
    let model: String?

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: provider.systemImage)
            Text(badgeText)
        }
        .font(.system(size: 7, weight: .black, design: .rounded))
        .tracking(0.55)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.black.opacity(0.045), in: Capsule())
    }

    private var badgeText: String {
        guard let model, model != "default" else { return provider.shortLabel }
        let compactModel = model.hasPrefix("gpt-") ? String(model.dropFirst(4)) : model.uppercased()
        return "\(provider.shortLabel) · \(compactModel)"
    }
}

private struct MiniControlKey: View {
    let eyebrow: String
    let value: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.black.opacity(0.12))
                    .offset(y: 3)

                VStack(spacing: 4) {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .semibold))

                    Text(value)
                        .font(.system(size: 9, weight: .black, design: .rounded))
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)

                    Text(eyebrow)
                        .font(.system(size: 6, weight: .bold, design: .monospaced))
                        .tracking(0.45)
                        .foregroundStyle(.tertiary)
                }
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .padding(.horizontal, 4)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LinearGradient(colors: [.white, Color(white: 0.94)], startPoint: .top, endPoint: .bottom))
                        .overlay { RoundedRectangle(cornerRadius: 14).stroke(.white, lineWidth: 1) }
                }
            }
        }
        .buttonStyle(TactileButtonStyle())
        .accessibilityLabel("\(eyebrow.capitalized), \(value)")
    }
}

private struct WorkflowPad: View {
    let workflows: [AgentWorkflow]
    let action: (AgentWorkflow) -> Void
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

    var body: some View {
        ZStack {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(AgentWorkflow.allCases, id: \.self) { workflow in
                    let supported = workflows.contains(workflow)
                    Button { action(workflow) } label: {
                        HStack(spacing: 7) {
                            Image(systemName: workflow.systemImage)
                                .font(.system(size: 14, weight: .bold))
                            Text(workflow.label)
                                .font(.system(size: 10, weight: .black, design: .rounded))
                                .lineLimit(1)
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(supported ? Color.primary : Color.secondary)
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 43)
                        .background {
                            RoundedRectangle(cornerRadius: 13, style: .continuous)
                                .fill(LinearGradient(colors: [.white, Color(white: 0.93)], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .overlay { RoundedRectangle(cornerRadius: 13).stroke(.white, lineWidth: 1) }
                                .shadow(color: .black.opacity(0.11), radius: 2, y: 3)
                        }
                    }
                    .buttonStyle(TactileButtonStyle())
                    .disabled(!supported)
                    .opacity(supported ? 1 : 0.42)
                }
            }

            JoystickPuck()
                .allowsHitTesting(false)
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 19, style: .continuous)
                .fill(.black.opacity(0.055))
                .overlay { RoundedRectangle(cornerRadius: 19).stroke(.white.opacity(0.74), lineWidth: 1) }
        }
    }
}

private struct JoystickPuck: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.22))
                .frame(width: 33, height: 33)
                .offset(y: 3)

            Circle()
                .fill(RadialGradient(colors: [Color(white: 0.28), .black], center: .topLeading, startRadius: 1, endRadius: 17))
                .overlay { Circle().stroke(.white.opacity(0.22), lineWidth: 1) }

            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.72))
        }
        .frame(width: 30, height: 30)
        .shadow(color: .black.opacity(0.26), radius: 5, y: 3)
    }
}

private struct ProviderControlSheet: View {
    @Bindable var store: AgentStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let agent = store.selectedAgent {
                        HStack(spacing: 11) {
                            Image(systemName: agent.provider.systemImage)
                                .font(.system(size: 20, weight: .bold))
                                .frame(width: 44, height: 44)
                                .background(.black, in: RoundedRectangle(cornerRadius: 13))
                                .foregroundStyle(.white)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(agent.provider.label)
                                    .font(.system(.headline, design: .rounded, weight: .bold))
                                Text("\(agent.harness) · \(agent.model)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if !agent.capabilities.models.isEmpty {
                            controlGroup(title: "Model", detail: modelDetail) {
                                ForEach(agent.capabilities.models, id: \.self) { model in
                                    SelectorCapsule(title: model, selected: agent.model == model) {
                                        Task { await store.perform(.setModel, text: model) }
                                    }
                                }
                            }
                        }

                        controlGroup(title: "Permission mode", detail: modeDetail) {
                            ForEach(agent.capabilities.modes, id: \.self) { mode in
                                SelectorCapsule(title: mode.label, selected: agent.mode == mode) {
                                    Task { await store.perform(.setMode, text: mode.rawValue) }
                                }
                            }
                        }

                        controlGroup(title: "Reasoning effort", detail: "Adapters must report only levels supported by the active model.") {
                            ForEach(agent.capabilities.efforts, id: \.self) { effort in
                                SelectorCapsule(title: effort.label, selected: agent.effort == effort) {
                                    Task { await store.perform(.setEffort, text: effort.rawValue) }
                                }
                            }
                        }

                        if agent.capabilities.speeds.count > 1 {
                            controlGroup(title: "Speed", detail: "Fast is capability-gated and may change usage or availability.") {
                                ForEach(agent.capabilities.speeds, id: \.self) { speed in
                                    SelectorCapsule(title: speed.label, selected: agent.speed == speed) {
                                        Task { await store.perform(.setSpeed, text: speed.rawValue) }
                                    }
                                }
                            }
                        }

                        if agent.capabilities.supportsWebSearch {
                            HStack(spacing: 12) {
                                Image(systemName: "globe.americas.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(width: 38, height: 38)
                                    .foregroundStyle(agent.webSearchEnabled ? .white : .primary)
                                    .background(agent.webSearchEnabled ? Color.blue : Color.white, in: RoundedRectangle(cornerRadius: 11))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Live web search")
                                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                                    Text("Codex can search current sources when the adapter supports it.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer(minLength: 8)

                                Toggle("Live web search", isOn: Binding(
                                    get: { agent.webSearchEnabled },
                                    set: { value in Task { await store.perform(.setWebSearch, text: String(value)) } }
                                ))
                                .labelsHidden()
                                .tint(.blue)
                            }
                            .padding(12)
                            .background(.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        if agent.capabilities.supportsResume || agent.capabilities.supportsFork {
                            controlGroup(title: "Session", detail: sessionDetail) {
                                if agent.capabilities.supportsResume {
                                    SessionActionButton(
                                        title: agent.provider == .claudeCode ? "Continue recent" : "Resume recent",
                                        systemImage: "clock.arrow.circlepath"
                                    ) {
                                        Task { await store.perform(.resumeSession) }
                                    }
                                }

                                if agent.capabilities.supportsFork {
                                    SessionActionButton(title: "Fork session", systemImage: "arrow.triangle.branch") {
                                        Task { await store.perform(.forkSession) }
                                    }
                                }
                            }
                        }

                        Text("AgentKeys sends typed semantic requests. The local adapter remains responsible for mapping them to a verified harness API and preserving native permission boundaries.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
            .background(Color(red: 0.95, green: 0.96, blue: 0.98))
            .navigationTitle("Agent controls")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var modeDetail: String {
        store.selectedAgent?.provider == .claudeCode
            ? "Safe Claude modes only. Permission bypass is intentionally unavailable."
            : "Switch between direct work and a plan-first collaboration flow."
    }

    private var modelDetail: String {
        store.selectedAgent?.provider == .claudeCode
            ? "Uses aliases advertised by Claude Code; the adapter resolves the active model."
            : "Only models advertised by the connected Codex adapter appear here."
    }

    private var sessionDetail: String {
        store.selectedAgent?.provider == .claudeCode
            ? "Continue the latest project session or fork it without replacing the original."
            : "Resume recent work or create an independent Codex session from the current context."
    }

    private func controlGroup<Content: View>(
        title: String,
        detail: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title)
                .font(.system(.subheadline, design: .rounded, weight: .bold))
            FlowLayout(spacing: 8) { content() }
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SessionActionButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.white, in: Capsule())
                .overlay { Capsule().stroke(.black.opacity(0.10), lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }
}

private struct BranchControlSheet: View {
    @Bindable var store: AgentStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Label("Isolated work", systemImage: "arrow.triangle.branch")
                    .font(.system(.title3, design: .rounded, weight: .bold))

                TextField("feat/my-change", text: $name)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
                    .padding(14)
                    .background(.black.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))

                Text("Queues a validated create-branch or worktree request. The adapter chooses the native mechanism supported by Codex or Claude Code.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    let branch = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    Task { await store.perform(.createBranch, text: branch) }
                    dismiss()
                } label: {
                    Label("Create isolated branch", systemImage: "plus")
                        .font(.system(.headline, design: .rounded, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.black)
                .disabled(!isValid)

                Spacer()
            }
            .padding(20)
            .background(Color(red: 0.95, green: 0.96, blue: 0.98))
            .navigationTitle("Branch / worktree")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { name = store.selectedAgent?.branch ?? "" }
        }
        .presentationDetents([.medium])
    }

    private var isValid: Bool {
        let value = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = value.split(separator: "/", omittingEmptySubsequences: false)
        guard (1...80).contains(value.count),
              !value.hasPrefix("-"), !value.hasPrefix("/"), !value.hasSuffix("/"), !value.hasSuffix("."),
              !value.contains(".."), !value.contains("//"),
              !components.contains(where: { $0.hasPrefix(".") || $0.hasSuffix(".lock") }) else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_/.")
        return value.unicodeScalars.allSatisfy(allowed.contains)
    }
}

private struct SelectorCapsule: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.caption, design: .rounded, weight: .bold))
                .foregroundStyle(selected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selected ? Color.black : Color.white, in: Capsule())
                .overlay { Capsule().stroke(.black.opacity(selected ? 0 : 0.10), lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

#Preview("Hardware control deck") {
    ControlDeckView(store: AgentStore())
        .preferredColorScheme(.light)
}
