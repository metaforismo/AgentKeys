import Foundation
import Security

/// Minimal Keychain wrapper for the pairing token. The address and port are
/// not secrets and live in UserDefaults; the bearer token never should.
enum KeychainStore {
    private static let service = "dev.agentkeys.connector"

    static func save(_ value: String, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let create = query.merging(attributes) { _, new in new }
            SecItemAdd(create as CFDictionary, nil)
        }
    }

    static func load(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// Persists the paired connector across launches so the app reconnects
/// automatically instead of booting into the demo.
enum ConnectorConfigurationStore {
    private static let schemeKey = "connector.scheme"
    private static let hostKey = "connector.host"
    private static let portKey = "connector.port"
    private static let tokenAccount = "phone-token"

    static func load(defaults: UserDefaults = .standard) -> ConnectorConfiguration? {
        let port = defaults.integer(forKey: portKey)
        guard let host = defaults.string(forKey: hostKey), !host.isEmpty,
              let scheme = defaults.string(forKey: schemeKey).flatMap(ConnectorScheme.init(rawValue:)),
              (1...65535).contains(port),
              let token = KeychainStore.load(account: tokenAccount), !token.isEmpty
        else { return nil }
        return ConnectorConfiguration(scheme: scheme, host: host, port: port, token: token)
    }

    static func save(_ configuration: ConnectorConfiguration, defaults: UserDefaults = .standard) {
        guard configuration != .demo else { return }
        defaults.set(configuration.scheme.rawValue, forKey: schemeKey)
        defaults.set(configuration.host, forKey: hostKey)
        defaults.set(configuration.port, forKey: portKey)
        KeychainStore.save(configuration.token, account: tokenAccount)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: schemeKey)
        defaults.removeObject(forKey: hostKey)
        defaults.removeObject(forKey: portKey)
        KeychainStore.delete(account: tokenAccount)
    }
}
