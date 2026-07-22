import Foundation

/// Secret storage abstraction. Configuration secrets (private keys, passwords)
/// are held here, never in plain `UserDefaults`. The app injects a Keychain-backed
/// implementation; tests and the core use ``InMemorySecureStore``.
public protocol SecureStore: Sendable {
    func setSecret(_ data: Data, for key: String) throws
    func secret(for key: String) throws -> Data?
    func deleteSecret(for key: String) throws
}

public extension SecureStore {
    func setString(_ value: String, for key: String) throws {
        try setSecret(Data(value.utf8), for: key)
    }
    func string(for key: String) throws -> String? {
        try secret(for: key).flatMap { String(data: $0, encoding: .utf8) }
    }
}

/// Thread-safe in-memory secret store (default in the core / tests).
public final class InMemorySecureStore: SecureStore, @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String: Data] = [:]

    public init() {}

    public func setSecret(_ data: Data, for key: String) throws {
        lock.lock(); defer { lock.unlock() }
        storage[key] = data
    }
    public func secret(for key: String) throws -> Data? {
        lock.lock(); defer { lock.unlock() }
        return storage[key]
    }
    public func deleteSecret(for key: String) throws {
        lock.lock(); defer { lock.unlock() }
        storage[key] = nil
    }
}
