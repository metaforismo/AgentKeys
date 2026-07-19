import Foundation
import Testing
@testable import AgentKeys

@Suite("AgentKeys model contract")
struct AgentKeysTests {
    @Test("connector configuration builds a bounded URL")
    func configurationURL() {
        let configuration = ConnectorConfiguration(scheme: .https, host: "agentkeys.example.test", port: 7777, token: "secret")
        #expect(configuration.baseURL?.absoluteString == "https://agentkeys.example.test:7777")
    }

    @Test("all wire statuses decode")
    func statusesDecode() throws {
        let data = Data("[\"idle\",\"thinking\",\"complete\",\"needs_input\",\"error\"]".utf8)
        let statuses = try JSONDecoder().decode([AgentStatus].self, from: data)
        #expect(statuses == AgentStatus.allCases)
    }

    @Test("legacy agents infer a safe provider profile")
    func legacyAgentDecode() throws {
        let json = """
        {
          "id":"73659c11-43ed-4aac-8f18-771b977c6901",
          "name":"Legacy","harness":"Claude Code","task":"Waiting","status":"idle",
          "updatedAt":"2026-07-17T10:00:00Z"
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let agent = try decoder.decode(Agent.self, from: Data(json.utf8))
        #expect(agent.provider == .claudeCode)
        #expect(agent.capabilities.modes == [.manual, .acceptEdits, .plan, .auto])
        #expect(agent.capabilities.speeds == [.standard])
        #expect(agent.capabilities.models == ["claude-fable-5", "claude-opus-4-8", "claude-sonnet-5", "claude-haiku-4-5"])
        #expect(agent.capabilities.supportsBranch)
        #expect(agent.capabilities.supportsResume)
        #expect(agent.capabilities.supportsFork)
        #expect(agent.model == "claude-fable-5")
    }

    @Test("provider profiles do not expose permission bypass")
    func providerProfilesAreBounded() {
        let codex = AgentCapabilities.defaults(for: .codex)
        #expect(codex.models == ["gpt-5.6-sol", "gpt-5.6-terra", "gpt-5.6-luna", "gpt-5.5", "gpt-5.3-codex-spark"])

        let claude = AgentCapabilities.defaults(for: .claudeCode)
        #expect(claude.modes == [.manual, .acceptEdits, .plan, .auto])
        #expect(claude.efforts.contains(.max))
        #expect(!claude.speeds.contains(.fast))
        #expect(!claude.supportsWebSearch)
        #expect(claude.models == ["claude-fable-5", "claude-opus-4-8", "claude-sonnet-5", "claude-haiku-4-5"])
    }

    @Test("model identifiers receive current human-readable labels")
    func modelPresentationLabels() {
        #expect(AgentModelPresentation.label(for: "gpt-5.6-sol", provider: .codex) == "5.6 Sol")
        #expect(AgentModelPresentation.label(for: "claude-fable-5", provider: .claudeCode) == "Fable 5")
        #expect(AgentModelPresentation.label(for: "opus[1m]", provider: .claudeCode) == "Opus 4.8 · 1M")
        #expect(AgentModelPresentation.label(for: "custom-model", provider: .generic) == "custom-model")
    }

    @Test("older capability payloads decode conservatively")
    func olderCapabilitiesDecode() throws {
        let json = """
        {
          "modes":["manual"],"efforts":["medium"],"speeds":["standard"],
          "workflows":[],"supportsBranch":false
        }
        """
        let capabilities = try JSONDecoder().decode(AgentCapabilities.self, from: Data(json.utf8))
        #expect(capabilities.models.isEmpty)
        #expect(!capabilities.supportsResume)
        #expect(!capabilities.supportsFork)
        #expect(!capabilities.supportsWebSearch)
    }
}
