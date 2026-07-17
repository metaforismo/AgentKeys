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
}

struct Agent: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    var harness: String
    var task: String
    var status: AgentStatus
    var updatedAt: Date
}

enum AgentAction: String, Codable, CaseIterable, Sendable {
    case approve
    case reject
    case interrupt
    case newChat = "new_chat"
    case prompt
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

