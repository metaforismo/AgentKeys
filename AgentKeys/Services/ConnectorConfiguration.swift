import Foundation

enum ConnectorScheme: String, Codable, CaseIterable, Sendable {
    case https
    case http

    var label: String {
        switch self {
        case .https: "HTTPS"
        case .http: "Local HTTP"
        }
    }
}

struct ConnectorConfiguration: Codable, Equatable, Sendable {
    var scheme: ConnectorScheme
    var host: String
    var port: Int
    var token: String

    static let demo = ConnectorConfiguration(scheme: .http, host: "127.0.0.1", port: 7777, token: "agentkeys-demo")

    var baseURL: URL? {
        var components = URLComponents()
        components.scheme = scheme.rawValue
        components.host = host
        components.port = port
        return components.url
    }
}
