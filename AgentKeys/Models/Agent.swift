import Foundation
import SwiftUI

enum AgentStatus: String, Codable, CaseIterable, Sendable {
    case idle
    case thinking
    case complete
    case needsInput = "needs_input"
    case error

    var label: String {
        switch self {
        case .idle: "Idle"
        case .thinking: "Thinking"
        case .complete: "Complete"
        case .needsInput: "Needs input"
        case .error: "Error"
        }
    }

    var color: Color {
        switch self {
        case .idle: Color(red: 0.69, green: 0.72, blue: 0.76)
        case .thinking: Color(red: 0.25, green: 0.44, blue: 0.98)
        case .complete: Color(red: 0.20, green: 0.72, blue: 0.46)
        case .needsInput: Color(red: 1.00, green: 0.63, blue: 0.20)
        case .error: Color(red: 0.95, green: 0.29, blue: 0.35)
        }
    }

    var assetName: String {
        switch self {
        case .idle: "StatusIdle"
        case .thinking: "StatusThinking"
        case .complete: "StatusComplete"
        case .needsInput: "StatusNeedsInput"
        case .error: "StatusError"
        }
    }
}

enum AgentProvider: String, Codable, CaseIterable, Sendable {
    case codex
    case claudeCode = "claude_code"
    case generic

    var label: String {
        switch self {
        case .codex: "Codex"
        case .claudeCode: "Claude Code"
        case .generic: "Custom"
        }
    }

    var shortLabel: String {
        switch self {
        case .codex: "CODEX"
        case .claudeCode: "CLAUDE"
        case .generic: "CUSTOM"
        }
    }

    var systemImage: String {
        switch self {
        case .codex: "chevron.left.forwardslash.chevron.right"
        case .claudeCode: "sparkles"
        case .generic: "cpu"
        }
    }
}

enum AgentMode: String, Codable, CaseIterable, Sendable {
    case manual
    case plan
    case acceptEdits = "accept_edits"
    case auto

    var label: String {
        switch self {
        case .manual: "Manual"
        case .plan: "Plan"
        case .acceptEdits: "Accept edits"
        case .auto: "Auto"
        }
    }
}

enum AgentEffort: String, Codable, CaseIterable, Sendable {
    case low
    case medium
    case high
    case xhigh
    case max

    var label: String { rawValue == "xhigh" ? "X-High" : rawValue.capitalized }
}

enum AgentSpeed: String, Codable, CaseIterable, Sendable {
    case standard
    case fast

    var label: String { rawValue.capitalized }
}

enum AgentWorkflow: String, Codable, CaseIterable, Sendable {
    case reviewPR = "review_pr"
    case debug
    case refactor
    case tests

    var label: String {
        switch self {
        case .reviewPR: "Review PR"
        case .debug: "Debug"
        case .refactor: "Refactor"
        case .tests: "Run tests"
        }
    }

    var systemImage: String {
        switch self {
        case .reviewPR: "arrow.triangle.branch"
        case .debug: "ladybug"
        case .refactor: "arrow.triangle.2.circlepath"
        case .tests: "checkmark.diamond"
        }
    }
}

struct AgentCapabilities: Codable, Equatable, Sendable {
    var modes: [AgentMode]
    var efforts: [AgentEffort]
    var speeds: [AgentSpeed]
    var workflows: [AgentWorkflow]
    var supportsBranch: Bool

    static func defaults(for provider: AgentProvider) -> Self {
        switch provider {
        case .codex:
            Self(
                modes: [.manual, .plan],
                efforts: [.low, .medium, .high, .xhigh],
                speeds: [.standard, .fast],
                workflows: AgentWorkflow.allCases,
                supportsBranch: true
            )
        case .claudeCode:
            Self(
                modes: [.manual, .acceptEdits, .plan, .auto],
                efforts: [.low, .medium, .high, .xhigh, .max],
                speeds: [.standard],
                workflows: AgentWorkflow.allCases,
                supportsBranch: true
            )
        case .generic:
            Self(modes: [.manual], efforts: [.medium], speeds: [.standard], workflows: [], supportsBranch: false)
        }
    }
}

struct Agent: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var harness: String
    var task: String
    var status: AgentStatus
    var updatedAt: Date
    var provider: AgentProvider
    var mode: AgentMode
    var effort: AgentEffort
    var speed: AgentSpeed
    var branch: String?
    var capabilities: AgentCapabilities

    init(
        id: UUID,
        name: String,
        harness: String,
        task: String,
        status: AgentStatus,
        updatedAt: Date,
        provider: AgentProvider? = nil,
        mode: AgentMode = .manual,
        effort: AgentEffort = .medium,
        speed: AgentSpeed = .standard,
        branch: String? = nil,
        capabilities: AgentCapabilities? = nil
    ) {
        let resolvedProvider = provider ?? Self.inferProvider(from: harness)
        self.id = id
        self.name = name
        self.harness = harness
        self.task = task
        self.status = status
        self.updatedAt = updatedAt
        self.provider = resolvedProvider
        self.mode = mode
        self.effort = effort
        self.speed = speed
        self.branch = branch
        self.capabilities = capabilities ?? .defaults(for: resolvedProvider)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, harness, task, status, updatedAt, provider, mode, effort, speed, branch, capabilities
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        harness = try container.decode(String.self, forKey: .harness)
        task = try container.decode(String.self, forKey: .task)
        status = try container.decode(AgentStatus.self, forKey: .status)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        provider = try container.decodeIfPresent(AgentProvider.self, forKey: .provider) ?? Self.inferProvider(from: harness)
        mode = try container.decodeIfPresent(AgentMode.self, forKey: .mode) ?? .manual
        effort = try container.decodeIfPresent(AgentEffort.self, forKey: .effort) ?? .medium
        speed = try container.decodeIfPresent(AgentSpeed.self, forKey: .speed) ?? .standard
        branch = try container.decodeIfPresent(String.self, forKey: .branch)
        capabilities = try container.decodeIfPresent(AgentCapabilities.self, forKey: .capabilities) ?? .defaults(for: provider)
    }

    private static func inferProvider(from harness: String) -> AgentProvider {
        if harness.localizedCaseInsensitiveContains("codex") { return .codex }
        if harness.localizedCaseInsensitiveContains("claude") { return .claudeCode }
        return .generic
    }
}

enum AgentAction: String, Codable, CaseIterable, Sendable {
    case approve
    case reject
    case interrupt
    case newChat = "new_chat"
    case prompt
    case setMode = "set_mode"
    case setEffort = "set_effort"
    case setSpeed = "set_speed"
    case createBranch = "create_branch"
    case workflow
}

struct ActionRequest: Codable, Sendable {
    let agentID: UUID
    let action: AgentAction
    let text: String?
    let requestID: UUID
}

struct ConnectorSnapshot: Codable, Sendable {
    let revision: Int
    let agents: [Agent]
}
