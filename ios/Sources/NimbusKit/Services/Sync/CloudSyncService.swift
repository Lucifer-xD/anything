import Foundation

/// A signed-in sync account.
public struct SyncAccount: Codable, Equatable, Sendable {
    public var email: String
    public var deviceID: String
    public var e2eEnabled: Bool
    public init(email: String, deviceID: String, e2eEnabled: Bool) {
        self.email = email
        self.deviceID = deviceID
        self.e2eEnabled = e2eEnabled
    }
}

/// Metadata about a stored backup (for "Manage cloud backups").
public struct SyncBackupInfo: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var deviceID: String
    public var configCount: Int
    public var encrypted: Bool
}

/// Cloud synchronization of the configuration library with optional end-to-end
/// encryption and conflict resolution.
public protocol CloudSyncService: Sendable {
    func account() async -> SyncAccount?
    func signIn(email: String, passphrase: String, e2eEnabled: Bool) async throws -> SyncAccount
    func signOut() async
    /// Push the local snapshot to the cloud (encrypting if E2E is on).
    func backup(_ snapshot: StoreSnapshot) async throws
    /// Pull and decrypt the latest cloud snapshot.
    func restore() async throws -> StoreSnapshot
    /// Two-way sync: pull remote, merge with local, push the merged result.
    func sync(local: StoreSnapshot, strategy: MergeStrategy) async throws -> SyncMergeResult
    func listBackups() async -> [SyncBackupInfo]
}

/// A fully-working local emulation of the cloud backend, backed by an in-memory
/// (or on-disk) encrypted envelope. It exercises the *entire* sync path — E2E
/// encryption, backup/restore, two-way merge, conflict resolution — so the
/// feature is testable without a real CloudKit/server backend. Production would
/// swap this for a `CloudKitSyncService` behind the same protocol.
public actor LocalMockCloudSyncService: CloudSyncService {
    private var currentAccount: SyncAccount?
    private var passphrase: String = ""
    private var cipher: ConfigurationCipher
    private var storedEnvelope: Data?
    private var backups: [SyncBackupInfo] = []
    private let clock: DateProviding
    private let encryptingCipher: ConfigurationCipher

    /// - Parameter encryptingCipher: used when E2E is enabled. Defaults to a
    ///   passthrough on platforms without CryptoKit; the app injects
    ///   `AESGCMCipher()`.
    public init(clock: DateProviding = SystemClock(), encryptingCipher: ConfigurationCipher = PassthroughCipher()) {
        self.clock = clock
        self.encryptingCipher = encryptingCipher
        self.cipher = PassthroughCipher()
    }

    public func account() -> SyncAccount? { currentAccount }

    public func signIn(email: String, passphrase: String, e2eEnabled: Bool) throws -> SyncAccount {
        guard email.contains("@") else { throw NimbusError.sync(reason: "invalid email") }
        let account = SyncAccount(email: email, deviceID: "this-device", e2eEnabled: e2eEnabled)
        currentAccount = account
        self.passphrase = passphrase
        self.cipher = e2eEnabled ? encryptingCipher : PassthroughCipher()
        return account
    }

    public func signOut() {
        currentAccount = nil
        passphrase = ""
        cipher = PassthroughCipher()
    }

    public func backup(_ snapshot: StoreSnapshot) throws {
        try requireAccount()
        let json = try encode(snapshot)
        storedEnvelope = try cipher.encrypt(json, passphrase: passphrase)
        backups.insert(SyncBackupInfo(
            id: UUID(),
            createdAt: clock.now(),
            deviceID: currentAccount?.deviceID ?? "unknown",
            configCount: snapshot.configs.count,
            encrypted: cipher.isEncrypting
        ), at: 0)
        if backups.count > 10 { backups.removeLast(backups.count - 10) }
    }

    public func restore() throws -> StoreSnapshot {
        try requireAccount()
        guard let storedEnvelope else { return StoreSnapshot() }
        let json = try cipher.decrypt(storedEnvelope, passphrase: passphrase)
        return try decode(json)
    }

    public func sync(local: StoreSnapshot, strategy: MergeStrategy) throws -> SyncMergeResult {
        try requireAccount()
        let remote = (try? restore()) ?? StoreSnapshot()
        let result = ConflictResolver.merge(local: local, remote: remote, strategy: strategy)
        try backup(result.merged)
        return result
    }

    public func listBackups() -> [SyncBackupInfo] { backups }

    // MARK: - Helpers

    private func requireAccount() throws {
        if currentAccount == nil { throw NimbusError.sync(reason: "not signed in") }
    }

    private func encode(_ snapshot: StoreSnapshot) throws -> Data {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601
        do { return try e.encode(snapshot) } catch { throw NimbusError.sync(reason: "encode failed: \(error)") }
    }

    private func decode(_ data: Data) throws -> StoreSnapshot {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
        do { return try d.decode(StoreSnapshot.self, from: data) } catch { throw NimbusError.sync(reason: "decode failed: \(error)") }
    }
}
