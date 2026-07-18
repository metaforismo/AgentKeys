import SwiftUI

/// The virtual macro pad: a frosted acrylic slab with RGB underglow, clear
/// RGB-backlit agent switches, matte thin-line command keycaps, a rotary
/// knob, a four-way stick, and silkscreen legends.
struct DeviceControlSurface: View {
    @Bindable var store: AgentStore
    @Bindable var recorder: SpeechPromptRecorder

    let onOpenControls: () -> Void
    let onOpenBranch: () -> Void
    let onOpenSettings: () -> Void

    private var selectedAgent: Agent? { store.selectedAgent }
    @ScaledMetric(relativeTo: .caption) private var textScale = 1.0

    var body: some View {
        VStack(spacing: 14) {
            masthead
            AcrylicSlab(accent: selectedAgent?.status.color) {
                boardLayout
            }
        }
    }

    // MARK: - Masthead

    private var masthead: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 5) {
                Text("AgentKeys")
                    .font(.system(size: 21, weight: .semibold))
                    .tracking(-0.4)
                    .foregroundStyle(DeckTheme.ink)

                Button(action: onOpenSettings) {
                    HStack(spacing: 6) {
                        DeckLED(color: connectionColor, size: 6)
                        Text(connectionChipText)
                            .font(.system(size: 9 * textScale, weight: .semibold))
                            .kerning(1.1)
                            .foregroundStyle(DeckTheme.silkscreen)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.75), in: Capsule())
                    .overlay { Capsule().stroke(.white, lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("deck-connection-chip")
                .accessibilityLabel("Connection: \(store.connectionState.label). Opens connector settings.")

                if let detail = store.connectionState.detail {
                    Text(detail)
                        .font(.system(size: 9))
                        .foregroundStyle(.red.opacity(0.85))
                        .lineLimit(1)
                }
            }

            Spacer()

            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(DeckTheme.ink.opacity(0.65))
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.85), in: Circle())
                    .overlay { Circle().stroke(.white, lineWidth: 1) }
                    .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
            }
            .buttonStyle(TactileButtonStyle())
            .accessibilityIdentifier("deck-settings")
            .accessibilityLabel("Connector settings")
        }
        .padding(.horizontal, 6)
    }

    // MARK: - Board

    private var boardLayout: some View {
        VStack(spacing: 13) {
            Image(systemName: "arrow.up")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(DeckTheme.silkscreen.opacity(0.7))
                .accessibilityHidden(true)

            // Row 1 — knob, first two agents, stick.
            HStack(alignment: .top, spacing: 10) {
                DeckKnob(caption: knobCaption, action: cycleMode)
                agentSlot(at: 0)
                agentSlot(at: 1)
                DeckJoystick(caption: "Control", action: onOpenControls)
            }

            // Row 2 — four more agent channels.
            HStack(alignment: .top, spacing: 10) {
                agentSlot(at: 2)
                agentSlot(at: 3)
                agentSlot(at: 4)
                agentSlot(at: 5)
            }

            statusDisplay

            // Row 3 — thin-line command keycaps.
            HStack(alignment: .top, spacing: 10) {
                commandKey(
                    id: "deck-key-stop",
                    icon: "bolt",
                    caption: "Stop",
                    enabled: selectedAgent?.status == .thinking
                ) {
                    Task { await store.perform(.interrupt) }
                }

                commandKey(
                    id: "deck-key-approve",
                    icon: "checkmark.circle",
                    caption: approveLabel,
                    enabled: selectedAgent?.status == .needsInput
                ) {
                    Task { await store.perform(.approve) }
                }

                commandKey(
                    id: "deck-key-reject",
                    icon: "xmark.circle",
                    caption: rejectLabel,
                    enabled: selectedAgent?.status == .needsInput
                ) {
                    Task { await store.perform(.reject) }
                }

                commandKey(
                    id: "deck-key-branch",
                    icon: "arrow.triangle.branch",
                    caption: "Branch",
                    enabled: selectedAgent?.capabilities.supportsBranch == true,
                    action: onOpenBranch
                )
            }

            // Row 4 — board details, wide mic bar, new-session key.
            HStack(alignment: .center, spacing: 10) {
                BoardDetailCluster()
                    .frame(width: 58)

                micBar

                MatteKeycap(
                    caption: "New",
                    enabled: selectedAgent != nil,
                    accessibilityID: "deck-key-new",
                    action: { Task { await store.perform(.newChat) } }
                ) {
                    CloudTerminalGlyph()
                }
                .frame(width: 76)
                .accessibilityLabel("New chat")
            }

            promptConsole

            Silkscreen(text: "Let’s build", size: 11, opacity: 0.7)
                .padding(.top, 1)
        }
    }

    // MARK: - Pieces

    @ViewBuilder
    private func agentSlot(at index: Int) -> some View {
        if store.agents.indices.contains(index) {
            let agent = store.agents[index]
            AgentSwitchKey(
                agent: agent,
                isSelected: store.selectedAgentID == agent.id,
                action: { store.selectedAgentID = agent.id }
            )
        } else {
            EmptySwitchKey(action: onOpenSettings)
        }
    }

    private func commandKey(
        id: String,
        icon: String,
        caption: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        MatteKeycap(caption: caption, enabled: enabled, accessibilityID: id, action: action) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .light))
        }
        .accessibilityLabel(caption)
    }

    /// Slim dark readout strip for the selected channel.
    private var statusDisplay: some View {
        HStack(spacing: 10) {
            if let agent = selectedAgent {
                DeckLED(color: agent.status.color, size: 8)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 7) {
                        Text(agent.name)
                            .font(.system(size: 13 * textScale, weight: .semibold))
                            .foregroundStyle(.white)

                        Text("\(agent.provider.shortLabel) · \(agent.model.uppercased()) · \(agent.effort.label.uppercased())")
                            .font(.system(size: 8 * textScale, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.45))
                            .lineLimit(1)
                    }

                    Text(agent.task)
                        .font(.system(size: 11 * textScale, weight: .regular))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineLimit(1)
                }

                Spacer(minLength: 6)

                Text(agent.status.label.uppercased())
                    .font(.system(size: 8 * textScale, weight: .semibold, design: .monospaced))
                    .kerning(0.8)
                    .foregroundStyle(agent.status.color)
            } else {
                Text("NO AGENT SELECTED")
                    .font(.system(size: 10 * textScale, weight: .semibold, design: .monospaced))
                    .kerning(1)
                    .foregroundStyle(.white.opacity(0.55))
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 13)
        .frame(maxWidth: .infinity, minHeight: 48)
        .background {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(white: 0.13), Color(white: 0.04)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .stroke(.white.opacity(0.16), lineWidth: 1)
                }
                .overlay(alignment: .top) {
                    // Glass gloss across the top of the display.
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.13), .clear],
                                startPoint: .top,
                                endPoint: .center
                            )
                        )
                        .allowsHitTesting(false)
                }
                .shadow(color: .black.opacity(0.18), radius: 5, y: 3)
        }
    }

    private var micBar: some View {
        MatteKeycap(
            caption: recorder.isRecording ? "Listening…" : "Push to talk",
            accessibilityID: "deck-push-to-talk",
            action: toggleRecording
        ) {
            Image(systemName: recorder.isRecording ? "waveform" : "mic")
                .font(.system(size: 20, weight: .light))
                .symbolEffect(.variableColor.iterative, isActive: recorder.isRecording)
                .foregroundStyle(recorder.isRecording ? Color.pink : DeckTheme.ink)
        }
        .frame(maxWidth: .infinity)
        .accessibilityHint("Uses Apple speech recognition to fill the prompt")
    }

    private var promptConsole: some View {
        HStack(spacing: 7) {
            TextField("Prompt selected agent", text: $store.prompt)
                .accessibilityIdentifier("deck-prompt-field")
                .font(.system(size: 13, weight: .regular))
                .submitLabel(.send)
                .onSubmit(sendPrompt)

            Button(action: sendPrompt) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 31, height: 31)
                    .background(DeckTheme.ink, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(TactileButtonStyle())
            .disabled(trimmedPrompt.isEmpty)
            .opacity(trimmedPrompt.isEmpty ? 0.35 : 1)
            .accessibilityIdentifier("deck-send-prompt")
            .accessibilityLabel("Send prompt")
        }
        .padding(.leading, 13)
        .padding(.trailing, 6)
        .frame(minHeight: 44)
        .background {
            // Recessed well: shaded top edge, bright bottom lip.
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.55))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.black.opacity(0.10), .white.opacity(0.9)],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }
        }
    }

    // MARK: - Derived state & actions

    private var trimmedPrompt: String {
        store.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var knobCaption: String {
        "Mode · \(selectedAgent?.mode.label ?? "—")"
    }

    private var approveLabel: String {
        selectedAgent?.provider == .claudeCode ? "Allow" : "Approve"
    }

    private var rejectLabel: String {
        selectedAgent?.provider == .claudeCode ? "Deny" : "Reject"
    }

    private var connectionColor: Color {
        switch store.connectionState {
        case .demo: .orange
        case .connecting: .blue
        case .connected: .green
        case .failed: .red
        }
    }

    private var connectionChipText: String {
        switch store.connectionState {
        case .demo: "DEMO · TAP TO PAIR"
        case .connecting: "CONNECTING…"
        case .connected: "CONNECTED"
        case .failed: "OFFLINE · TAP TO FIX"
        }
    }

    private func cycleMode() {
        Task { await store.cycleMode() }
    }

    private func sendPrompt() {
        let prompt = trimmedPrompt
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

// MARK: - Cloud terminal glyph

/// The cloud badge with a tiny prompt inside, from the bottom-right keycap.
private struct CloudTerminalGlyph: View {
    var body: some View {
        ZStack {
            Image(systemName: "cloud")
                .font(.system(size: 22, weight: .light))

            Text("›_")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .offset(y: 1)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Acrylic slab

/// Frosted translucent chassis with an RGB glow ring bleeding out of the
/// acrylic edge, corner screws, and vertical silkscreen legends.
private struct AcrylicSlab<Content: View>: View {
    var accent: Color?
    @ViewBuilder let content: Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast

    var body: some View {
        content
            .padding(.horizontal, 22)
            .padding(.top, 14)
            .padding(.bottom, 12)
            .background { chassis }
    }

    private var chassis: some View {
        ZStack {
            // RGB underglow escaping around the acrylic edge: a wide floor
            // bloom plus a tight saturated rim hugging the chassis.
            RoundedRectangle(cornerRadius: 36, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: glowColors,
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    )
                )
                .padding(3)
                .blur(radius: 18)
                .offset(y: 10)
                .opacity(reduceTransparency ? 0.35 : 0.8)

            RoundedRectangle(cornerRadius: 35, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: glowColors,
                        startPoint: .topTrailing,
                        endPoint: .bottomLeading
                    ),
                    lineWidth: 5
                )
                .padding(1)
                .blur(radius: 5)
                .opacity(reduceTransparency ? 0.25 : 0.55)

            // Frosted acrylic body.
            RoundedRectangle(cornerRadius: 34, style: .continuous)
                .fill(
                    reduceTransparency
                        ? AnyShapeStyle(Color(red: 0.93, green: 0.94, blue: 0.95))
                        : AnyShapeStyle(.ultraThinMaterial)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.72), .white.opacity(0.30)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 34, style: .continuous)
                        .stroke(
                            colorSchemeContrast == .increased
                                ? Color.primary.opacity(0.4)
                                : Color.white.opacity(0.95),
                            lineWidth: 1.25
                        )
                }
                .overlay {
                    // Inner plate seam.
                    RoundedRectangle(cornerRadius: 27, style: .continuous)
                        .stroke(.black.opacity(0.07), lineWidth: 1)
                        .padding(7)
                }
                .shadow(color: .black.opacity(0.14), radius: 18, y: 12)

            edgeLegends
            screws
        }
    }

    private var glowColors: [Color] {
        if let accent, accent != AgentStatus.idle.color {
            return [DeckTheme.glow[0], DeckTheme.glow[1], accent.opacity(0.9), DeckTheme.glow[3]]
        }
        return DeckTheme.glow
    }

    private var edgeLegends: some View {
        ZStack {
            Silkscreen(text: "AGENTKEYS  |  2026", size: 8.5)
                .fixedSize()
                .rotationEffect(.degrees(-90))
                .frame(width: 13)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.leading, 3)

            Silkscreen(text: "You can just build things", size: 8.5)
                .fixedSize()
                .rotationEffect(.degrees(90))
                .frame(width: 13)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.trailing, 3)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var screws: some View {
        VStack {
            HStack { DeckScrew(); Spacer(); DeckScrew() }
            Spacer()
            HStack { DeckScrew(); Spacer(); DeckScrew() }
        }
        .padding(13)
        .allowsHitTesting(false)
    }
}

#Preview("Virtual device") {
    ScrollView {
        DeviceControlSurface(
            store: AgentStore(),
            recorder: SpeechPromptRecorder(),
            onOpenControls: {},
            onOpenBranch: {},
            onOpenSettings: {}
        )
        .padding(16)
    }
    .background(DeckTheme.studio)
}
