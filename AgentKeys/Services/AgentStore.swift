import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class AgentStore {
    var agents: [Agent]
    var selectedAgentID: UUID?
    var configuration: ConnectorConfiguration
    var connectionState: ConnectionState = .demo
    var prompt = ""
    var isSettingsPresented = false

    private let client: ConnectorClient
    private var pollTask: Task<Void, Never>?

    enum ConnectionState: Equatable {
        case demo
        case connecting
        case connected
        case failed(String)

        var label: String {
            switch self {
            case .demo: "Demo"
            case .connecting: "Connecting"
            case .connected: "Connected"
            case .failed: "Offline"
            }
        }
    }

    init(client: ConnectorClient = ConnectorClient()) {
        self.client = client
        configuration = .demo
        agents = Self.fixtures
        selectedAgentID = agents.first?.id
    }

    var selectedAgent: Agent? {
        agents.first { $0.id == selectedAgentID }
    }

    func startPolling() {
        guard pollTask == nil, connectionState != .demo else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refresh() async {
        connectionState = .connecting
        do {
            let snapshot = try await client.snapshot(configuration: configuration)
            agents = snapshot.agents
            if !agents.contains(where: { $0.id == selectedAgentID }) {
                selectedAgentID = agents.first?.id
            }
            connectionState = .connected
        } catch is CancellationError {
            return
        } catch {
            if configuration == .demo {
                agents = Self.fixtures
                connectionState = .demo
            } else {
                connectionState = .failed(error.localizedDescription)
            }
        }
    }

    func perform(_ action: AgentAction, text: String? = nil) async {
        guard let selectedAgentID else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        if connectionState == .demo {
            applyDemo(action, to: selectedAgentID, text: text)
            return
        }

        do {
            try await client.send(
                ActionRequest(agentID: selectedAgentID, action: action, text: text, requestID: UUID()),
                configuration: configuration
            )
            if action == .prompt { prompt = "" }
            await refresh()
        } catch {
            connectionState = .failed(error.localizedDescription)
        }
    }

    func cycleMode() async {
        guard let agent = selectedAgent,
              let value = next(after: agent.mode, in: agent.capabilities.modes) else { return }
        await perform(.setMode, text: value.rawValue)
    }

    func cycleEffort() async {
        guard let agent = selectedAgent,
              let value = next(after: agent.effort, in: agent.capabilities.efforts) else { return }
        await perform(.setEffort, text: value.rawValue)
    }

    func cycleSpeed() async {
        guard let agent = selectedAgent,
              let value = next(after: agent.speed, in: agent.capabilities.speeds),
              agent.capabilities.speeds.count > 1 else { return }
        await perform(.setSpeed, text: value.rawValue)
    }

    func run(_ workflow: AgentWorkflow) async {
        guard selectedAgent?.capabilities.workflows.contains(workflow) == true else { return }
        await perform(.workflow, text: workflow.rawValue)
    }

    func useDemo() {
        stopPolling()
        configuration = .demo
        agents = Self.fixtures
        selectedAgentID = agents.first?.id
        connectionState = .demo
    }

    func connect() {
        stopPolling()
        connectionState = .connecting
        startPolling()
    }

    private func applyDemo(_ action: AgentAction, to id: UUID, text: String?) {
        guard let index = agents.firstIndex(where: { $0.id == id }) else { return }
        switch action {
        case .approve: agents[index].status = .thinking
        case .reject, .interrupt: agents[index].status = .idle
        case .newChat: agents[index].task = "New conversation"; agents[index].status = .idle
        case .prompt:
            agents[index].task = text.flatMap { $0.isEmpty ? nil : $0 } ?? "Voice prompt"
            agents[index].status = .thinking
            prompt = ""
        case .setMode:
            if let text, let value = AgentMode(rawValue: text), agents[index].capabilities.modes.contains(value) {
                agents[index].mode = value
            }
        case .setEffort:
            if let text, let value = AgentEffort(rawValue: text), agents[index].capabilities.efforts.contains(value) {
                agents[index].effort = value
            }
        case .setSpeed:
            if let text, let value = AgentSpeed(rawValue: text), agents[index].capabilities.speeds.contains(value) {
                agents[index].speed = value
            }
        case .createBranch:
            agents[index].branch = text
            agents[index].task = "Preparing isolated branch"
            agents[index].status = .thinking
        case .workflow:
            if let text, let workflow = AgentWorkflow(rawValue: text) {
                agents[index].task = workflow.label
                agents[index].status = .thinking
            }
        }
        agents[index].updatedAt = .now
    }

    static let fixtures: [Agent] = [
        Agent(id: UUID(uuidString: "73659C11-43ED-4AAC-8F18-771B977C6901")!, name: "Codex", harness: "Codex CLI", task: "Implement connector protocol", status: .thinking, updatedAt: .now, provider: .codex, effort: .high, speed: .fast, branch: "feat/control-deck"),
        Agent(id: UUID(uuidString: "8FB44C64-D268-4728-BDC8-89C0AC9CAAD2")!, name: "Review", harness: "Codex", task: "Review security boundary", status: .needsInput, updatedAt: .now, provider: .codex, mode: .plan, effort: .xhigh, branch: "review/security"),
        Agent(id: UUID(uuidString: "FC2E5070-041C-4AD2-A90E-959A34AF3BBF")!, name: "Design", harness: "Claude Code", task: "Polish tactile controls", status: .complete, updatedAt: .now, provider: .claudeCode, mode: .acceptEdits, effort: .high, branch: "design/hardware-ui"),
        Agent(id: UUID(uuidString: "C8C71A25-245B-4EAB-92A3-A03C39A9FA08")!, name: "Docs", harness: "Generic", task: "Waiting for work", status: .idle, updatedAt: .now),
        Agent(id: UUID(uuidString: "25D4EE53-91E4-4B40-91EE-B33FE5472A2A")!, name: "Tests", harness: "Codex", task: "Simulator smoke test", status: .error, updatedAt: .now, provider: .codex, effort: .medium, branch: "test/smoke")
    ]

    private func next<T: Equatable>(after current: T, in values: [T]) -> T? {
        guard !values.isEmpty else { return nil }
        guard let index = values.firstIndex(of: current) else { return values.first }
        return values[(index + 1) % values.count]
    }
}
