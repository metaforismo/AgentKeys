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
        #expect(agent.capabilities.models == ["sonnet", "opus", "haiku"])
        #expect(agent.capabilities.supportsBranch)
        #expect(agent.capabilities.supportsResume)
        #expect(agent.capabilities.supportsFork)
        #expect(agent.model == "sonnet")
    }

    @Test("provider profiles do not expose permission bypass")
    func providerProfilesAreBounded() {
        let claude = AgentCapabilities.defaults(for: .claudeCode)
        #expect(claude.modes == [.manual, .acceptEdits, .plan, .auto])
        #expect(claude.efforts.contains(.max))
        #expect(!claude.speeds.contains(.fast))
        #expect(!claude.supportsWebSearch)
        #expect(claude.models == ["sonnet", "opus", "haiku"])
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
