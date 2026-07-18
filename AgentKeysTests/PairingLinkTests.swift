import Foundation
import Testing
@testable import AgentKeys

@Suite("Pairing link contract")
struct PairingLinkTests {
    @Test("valid pairing link parses into a configuration")
    func validLinkParses() {
        let link = "agentkeys://pair?v=1&scheme=http&host=100.101.102.103&port=7777&token=JSB1RoanxG92yTcQ0L5yX4JO"
        let configuration = PairingLink.parse(link)
        #expect(configuration?.scheme == .http)
        #expect(configuration?.host == "100.101.102.103")
        #expect(configuration?.port == 7777)
        #expect(configuration?.token == "JSB1RoanxG92yTcQ0L5yX4JO")
    }

    @Test("https scheme is preserved")
    func httpsParses() {
        let configuration = PairingLink.parse("agentkeys://pair?scheme=https&host=mac.tailnet.ts.net&port=443&token=abcdefghijkl")
        #expect(configuration?.scheme == .https)
        #expect(configuration?.port == 443)
    }

    @Test("wrong scheme, host, or malformed fields are rejected")
    func invalidLinksRejected() {
        #expect(PairingLink.parse("https://pair?scheme=http&host=a&port=1&token=abcdefghijkl") == nil)
        #expect(PairingLink.parse("agentkeys://settings?scheme=http&host=a&port=1&token=abcdefghijkl") == nil)
        #expect(PairingLink.parse("agentkeys://pair?scheme=ftp&host=a&port=1&token=abcdefghijkl") == nil)
        #expect(PairingLink.parse("agentkeys://pair?scheme=http&host=&port=1&token=abcdefghijkl") == nil)
        #expect(PairingLink.parse("agentkeys://pair?scheme=http&host=a&port=0&token=abcdefghijkl") == nil)
        #expect(PairingLink.parse("agentkeys://pair?scheme=http&host=a&port=99999&token=abcdefghijkl") == nil)
        #expect(PairingLink.parse("agentkeys://pair?scheme=http&host=a&port=1&token=short") == nil)
        #expect(PairingLink.parse("not a url at all") == nil)
    }

    @Test("parsing tolerates surrounding whitespace from the clipboard")
    func whitespaceTolerated() {
        let configuration = PairingLink.parse("  agentkeys://pair?scheme=http&host=192.168.1.4&port=7777&token=abcdefghijkl\n")
        #expect(configuration != nil)
    }
}
