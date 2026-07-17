import Foundation

enum ConnectorError: LocalizedError {
    case invalidConfiguration
    case invalidResponse
    case server(Int)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration: "The connector address is invalid."
        case .invalidResponse: "The connector returned an invalid response."
        case .server(let status): "The connector returned HTTP \(status)."
        }
    }
}

actor ConnectorClient {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(session: URLSession = .shared) {
        self.session = session
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
    }

    func snapshot(configuration: ConnectorConfiguration) async throws -> ConnectorSnapshot {
        let request = try request(path: "/v1/snapshot", method: "GET", configuration: configuration)
        let (data, response) = try await session.data(for: request)
        try validate(response)
        return try decoder.decode(ConnectorSnapshot.self, from: data)
    }

    func send(_ action: ActionRequest, configuration: ConnectorConfiguration) async throws {
        var request = try request(path: "/v1/actions", method: "POST", configuration: configuration)
        request.httpBody = try encoder.encode(action)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let (_, response) = try await session.data(for: request)
        try validate(response)
    }

    private func request(path: String, method: String, configuration: ConnectorConfiguration) throws -> URLRequest {
        guard let url = configuration.baseURL?.appending(path: path) else {
            throw ConnectorError.invalidConfiguration
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 4
        request.setValue("Bearer \(configuration.token)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw ConnectorError.invalidResponse }
        guard 200..<300 ~= http.statusCode else { throw ConnectorError.server(http.statusCode) }
    }
}

