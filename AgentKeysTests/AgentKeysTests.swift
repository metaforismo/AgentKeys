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
}
