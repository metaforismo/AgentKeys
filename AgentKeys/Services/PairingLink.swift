import Foundation

/// Parses the `agentkeys://pair` deep link printed (and rendered as a QR
/// code) by the Mac connector, so pairing never requires typing an address
/// or token by hand.
enum PairingLink {
    static func parse(_ url: URL) -> ConnectorConfiguration? {
        guard url.scheme?.lowercased() == "agentkeys" else { return nil }
        let target = (url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))).lowercased()
        guard target == "pair",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }

        var values: [String: String] = [:]
        for item in components.queryItems ?? [] {
            values[item.name] = item.value
        }

        guard let scheme = values["scheme"].flatMap(ConnectorScheme.init(rawValue:)),
              let host = values["host"], !host.isEmpty, host.count <= 253,
              let port = values["port"].flatMap(Int.init), (1...65535).contains(port),
              let token = values["token"], token.count >= 12, token.count <= 128
        else { return nil }

        return ConnectorConfiguration(scheme: scheme, host: host, port: port, token: token)
    }

    static func parse(_ text: String) -> ConnectorConfiguration? {
        guard let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        return parse(url)
    }
}
