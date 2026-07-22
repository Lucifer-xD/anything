import XCTest
@testable import NimbusKit

final class SyncTests: XCTestCase {
    // MARK: Conflict resolution

    private func config(_ id: String, name: String, updated: TimeInterval) -> TunnelConfiguration {
        var f = ConfigFields(); f.set(FieldKey.name, name); f.set(FieldKey.server, "h"); f.set(FieldKey.port, 443)
        var meta = ConfigMetadata()
        meta.createdAt = Date(timeIntervalSince1970: 1) // fixed so identical configs compare equal
        meta.updatedAt = Date(timeIntervalSince1970: updated)
        return TunnelConfiguration(id: UUID(uuidString: id)!, kind: .trojan, fields: f, metadata: meta)
    }

    func testMergeAddsRemoteOnly() {
        let local = StoreSnapshot(configs: [config("00000000-0000-0000-0000-000000000001", name: "A", updated: 100)])
        let remote = StoreSnapshot(configs: [
            config("00000000-0000-0000-0000-000000000001", name: "A", updated: 100),
            config("00000000-0000-0000-0000-000000000002", name: "B", updated: 100),
        ])
        let result = ConflictResolver.merge(local: local, remote: remote)
        XCTAssertEqual(result.merged.configs.count, 2)
        XCTAssertEqual(result.addedIDs.count, 1)
        XCTAssertTrue(result.conflictIDs.isEmpty)
    }

    func testMergeNewerWins() {
        let id = "00000000-0000-0000-0000-000000000001"
        let local = StoreSnapshot(configs: [config(id, name: "Local", updated: 100)])
        let remote = StoreSnapshot(configs: [config(id, name: "Remote", updated: 200)])
        let result = ConflictResolver.merge(local: local, remote: remote, strategy: .newerWins)
        XCTAssertEqual(result.merged.configs.first?.name, "Remote")
        XCTAssertEqual(result.conflictIDs.count, 1)
        XCTAssertEqual(result.updatedIDs.count, 1)
    }

    func testMergePreferLocal() {
        let id = "00000000-0000-0000-0000-000000000001"
        let local = StoreSnapshot(configs: [config(id, name: "Local", updated: 100)])
        let remote = StoreSnapshot(configs: [config(id, name: "Remote", updated: 999)])
        let result = ConflictResolver.merge(local: local, remote: remote, strategy: .preferLocal)
        XCTAssertEqual(result.merged.configs.first?.name, "Local")
    }

    // MARK: Passthrough cipher

    func testPassthroughCipherIsIdentity() throws {
        let cipher = PassthroughCipher()
        let data = Data("secret".utf8)
        XCTAssertEqual(try cipher.encrypt(data, passphrase: "pw"), data)
        XCTAssertEqual(try cipher.decrypt(data, passphrase: "pw"), data)
        XCTAssertFalse(cipher.isEncrypting)
    }

    #if canImport(CryptoKit)
    func testAESGCMRoundTrip() throws {
        let cipher = AESGCMCipher()
        let data = Data("top secret configuration".utf8)
        let encrypted = try cipher.encrypt(data, passphrase: "correct horse")
        XCTAssertNotEqual(encrypted, data)
        XCTAssertEqual(try cipher.decrypt(encrypted, passphrase: "correct horse"), data)
        XCTAssertThrowsError(try cipher.decrypt(encrypted, passphrase: "wrong"))
    }
    #endif

    // MARK: Cloud sync service

    func testCloudBackupRestore() async throws {
        let sync = LocalMockCloudSyncService()
        _ = try await sync.signIn(email: "a@b.com", passphrase: "pw", e2eEnabled: false)
        let snapshot = SampleData.snapshot
        try await sync.backup(snapshot)
        let restored = try await sync.restore()
        XCTAssertEqual(restored.configs.count, snapshot.configs.count)
        let backups = await sync.listBackups()
        XCTAssertEqual(backups.count, 1)
    }

    func testCloudSyncMerges() async throws {
        let sync = LocalMockCloudSyncService()
        _ = try await sync.signIn(email: "a@b.com", passphrase: "pw", e2eEnabled: false)
        // Seed remote with one config.
        let remote = StoreSnapshot(configs: [config("00000000-0000-0000-0000-0000000000FF", name: "Remote", updated: 100)])
        try await sync.backup(remote)
        // Local has a different config; sync should merge to two.
        let local = StoreSnapshot(configs: [config("00000000-0000-0000-0000-0000000000AA", name: "Local", updated: 100)])
        let result = try await sync.sync(local: local, strategy: .newerWins)
        XCTAssertEqual(result.merged.configs.count, 2)
    }

    func testSyncRequiresSignIn() async {
        let sync = LocalMockCloudSyncService()
        do {
            try await sync.backup(SampleData.snapshot)
            XCTFail("expected not-signed-in error")
        } catch {
            // expected
        }
    }
}
