import Foundation
import NimbusKit
#if canImport(Security)
import Security
#endif

/// Production ``SecureStore`` backed by the iOS Keychain (`kSecClassGenericPassword`),
/// scoped to the app's keychain-access-group so secrets are shared with the
/// tunnel extension.
struct KeychainSecureStore: SecureStore {
    private let service: String
    init(service: String = "net.nimbus.vpn") { self.service = service }

    #if canImport(Security)
    private func query(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: key]
    }

    func setSecret(_ data: Data, for key: String) throws {
        var attributes = query(key)
        SecItemDelete(attributes as CFDictionary)
        attributes[kSecValueData as String] = data
        attributes[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw NimbusError.storage(reason: "keychain add \(status)") }
    }

    func secret(for key: String) throws -> Data? {
        var attributes = query(key)
        attributes[kSecReturnData as String] = true
        attributes[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(attributes as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw NimbusError.storage(reason: "keychain read \(status)") }
        return result as? Data
    }

    func deleteSecret(for key: String) throws {
        let status = SecItemDelete(query(key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw NimbusError.storage(reason: "keychain delete \(status)")
        }
    }
    #else
    func setSecret(_ data: Data, for key: String) throws {}
    func secret(for key: String) throws -> Data? { nil }
    func deleteSecret(for key: String) throws {}
    #endif
}
