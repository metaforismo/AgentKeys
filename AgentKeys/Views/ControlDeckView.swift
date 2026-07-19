import SwiftUI

struct ControlDeckView: View {
    @Bindable var store: AgentStore
    @State private var recorder = SpeechPromptRecorder()
    @State private var activeSheet: DeckSheet?
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
#if DEBUG
    private let launchesControlsForUITesting: Bool
#endif

    init(store: AgentStore) {
        self.store = store
#if DEBUG
        launchesControlsForUITesting = ProcessInfo.processInfo.arguments.contains("-ui-testing-controls")
#endif
    }

    var body: some View {
        NavigationStack {
            ZStack {
                StudioBackground()

                ScrollView {
                    if horizontalSizeClass == .regular {
                        VStack(spacing: 0) {
                            Spacer(minLength: 40)
                            deckSurface
                                .frame(maxWidth: 680)
                            Spacer(minLength: 40)
                        }
                        .frame(maxWidth: .infinity)
                        .containerRelativeFrame(.vertical)
                    } else {
                        deckSurface
                            .frame(maxWidth: 560)
                            .frame(maxWidth: .infinity)
                    }
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
#if DEBUG
                if launchesControlsForUITesting {
                    activeSheet = .controls
                }
#endif
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

    private var deckSurface: some View {
        DeviceControlSurface(
            store: store,
            recorder: recorder,
            onOpenControls: { activeSheet = .controls },
            onOpenBranch: { activeSheet = .branch },
            onOpenSettings: { activeSheet = .settings }
        )
        .padding(.horizontal, 14)
        .padding(.top, 18)
        .padding(.bottom, 28)
    }
}

private enum DeckSheet: String, Identifiable {
    case controls
    case branch
    case settings

    var id: String { rawValue }
}

/// Neutral studio backdrop — the seamless white sweep behind the product shots.
private struct StudioBackground: View {
    var body: some View {
        ZStack {
            DeckTheme.studio

            RadialGradient(
                colors: [.white.opacity(0.8), .clear],
                center: .top,
                startRadius: 20,
                endRadius: 420
            )

            // Faint color bounce from the underglow onto the table.
            RadialGradient(
                colors: [DeckTheme.glow[1].opacity(0.10), .clear],
                center: .bottom,
                startRadius: 20,
                endRadius: 380
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Provider controls sheet

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
                                .font(.system(size: 20, weight: .medium))
                                .frame(width: 44, height: 44)
                                .background(DeckTheme.ink, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                                .foregroundStyle(.white)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(agent.provider.label)
                                    .font(.system(.headline, weight: .semibold))
                                Text("\(agent.harness) · \(agent.modelDisplayName)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        if !agent.capabilities.models.isEmpty {
                            controlGroup(title: "Model", detail: modelDetail) {
                                ForEach(agent.capabilities.models, id: \.self) { model in
                                    SelectorCapsule(
                                        title: AgentModelPresentation.label(for: model, provider: agent.provider),
                                        selected: agent.model == model
                                    ) {
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
                                Image(systemName: "globe.americas")
                                    .font(.system(size: 16, weight: .medium))
                                    .frame(width: 38, height: 38)
                                    .foregroundStyle(agent.webSearchEnabled ? .white : .primary)
                                    .background(
                                        agent.webSearchEnabled ? Color.blue : Color.white,
                                        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    )

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Live web search")
                                        .font(.system(.subheadline, weight: .semibold))
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
                            .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }

                        if !agent.capabilities.workflows.isEmpty {
                            controlGroup(title: "Macros", detail: "Run a provider-supported workflow on the selected agent.") {
                                ForEach(agent.capabilities.workflows, id: \.self) { workflow in
                                    SessionActionButton(title: workflow.label, systemImage: workflow.systemImage) {
                                        Task { await store.run(workflow) }
                                    }
                                }
                            }
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
            .background(DeckTheme.studio)
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
                .font(.system(.subheadline, weight: .semibold))
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
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(.white, in: Capsule())
                .overlay { Capsule().stroke(.black.opacity(0.10), lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Branch sheet

private struct BranchControlSheet: View {
    @Bindable var store: AgentStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Label("Isolated work", systemImage: "arrow.triangle.branch")
                    .font(.system(.title3, weight: .semibold))

                TextField("feat/my-change", text: $name)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.system(.body, design: .monospaced))
                    .padding(14)
                    .background(.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text("Queues a validated create-branch or worktree request. The adapter chooses the native mechanism supported by Codex or Claude Code.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    let branch = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    Task { await store.perform(.createBranch, text: branch) }
                    dismiss()
                } label: {
                    Label("Create isolated branch", systemImage: "plus")
                        .font(.system(.headline, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(DeckTheme.ink)
                .disabled(!isValid)

                Spacer()
            }
            .padding(20)
            .background(DeckTheme.studio)
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

// MARK: - Shared sheet controls

private struct SelectorCapsule: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(selected ? .white : .primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selected ? DeckTheme.ink : Color.white, in: Capsule())
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

#Preview("Control deck") {
    ControlDeckView(store: AgentStore())
        .preferredColorScheme(.light)
}
