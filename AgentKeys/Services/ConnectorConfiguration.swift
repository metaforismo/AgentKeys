import Foundation

struct ConnectorConfiguration: Codable, Equatable, Sendable {
    var host: String
    var port: Int
    var token: String

    static let demo = ConnectorConfiguration(host: "127.0.0.1", port: 7777, token: "agentkeys-demo")

    var baseURL: URL? {
        var components = URLComponents()
        components.scheme = "http"
        components.host = host
        components.port = port
        return components.url
    }
}

