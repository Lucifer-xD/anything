import XCTest
@testable import NimbusKit

final class StoreTests: XCTestCase {
    private func makeStore(seeded: Bool = false) -> DefaultConfigurationStore {
        DefaultConfigurationStore(clock: MutableClock(), seed: seeded ? SampleData.snapshot : nil)
    }

    func testSaveAndFetch() async throws {
        let store = makeStore()
        var f = ConfigFields(); f.set(FieldKey.name, "Test"); f.set(FieldKey.server, "h"); f.set(FieldKey.port, 443); f.set(FieldKey.password, "p")
        let config = TunnelConfiguration(kind: .trojan, fields: f)
        try await store.save(config)
        let fetched = await store.configuration(id: config.id)
        XCTAssertEqual(fetched?.name, "Test")
        let count = await store.allConfigurations().count
        XCTAssertEqual(count, 1)
    }

    func testDefaultFoldersSeeded() async {
        let store = makeStore()
        let folders = await store.folders()
        XCTAssertEqual(folders.count, ConfigFolder.defaults.count)
        XCTAssertEqual(folders.first?.name, "Personal")
    }

    func testDuplicateDeleteFavoritePin() async throws {
        let store = makeStore(seeded: true)
        let first = await store.allConfigurations().first!
        let copy = try await store.duplicate(id: first.id)
        let countAfterDup = await store.allConfigurations().count
        XCTAssertEqual(countAfterDup, SampleData.configurations.count + 1)
        XCTAssertTrue(copy.name.hasSuffix("Copy"))

        try await store.setFavorite(copy.id, true)
        try await store.setPinned(copy.id, true)
        let updated = await store.configuration(id: copy.id)
        XCTAssertTrue(updated?.metadata.isFavorite == true)
        XCTAssertTrue(updated?.metadata.isPinned == true)

        try await store.delete(id: copy.id)
        let afterDelete = await store.configuration(id: copy.id)
        XCTAssertNil(afterDelete)
    }

    func testMoveToFolderUpdatesGroup() async throws {
        let store = makeStore(seeded: true)
        let config = await store.allConfigurations().first!
        let work = ConfigFolder.defaults[1]
        try await store.move(config.id, toFolder: work.id)
        let moved = await store.configuration(id: config.id)
        XCTAssertEqual(moved?.metadata.folderID, work.id)
        XCTAssertEqual(moved?.metadata.group, "Work")
    }

    func testImportDedupesById() async throws {
        let store = makeStore()
        let config = SampleData.configurations[0]
        try await store.importConfigurations([config, config])
        let count = await store.allConfigurations().count
        XCTAssertEqual(count, 1)
    }

    func testSubscriptionsCRUD() async throws {
        let store = makeStore()
        let sub = SampleData.subscriptions[0]
        try await store.saveSubscription(sub)
        let afterSave = await store.subscriptions().count
        XCTAssertEqual(afterSave, 1)
        try await store.deleteSubscription(id: sub.id)
        let afterDelete = await store.subscriptions().count
        XCTAssertEqual(afterDelete, 0)
    }

    func testPersistenceRoundTrip() async throws {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("nimbus-test-\(UUID().uuidString)")
        let persistence = FilePersistence(directory: dir)
        let store1 = DefaultConfigurationStore(persistence: persistence, clock: MutableClock())
        var f = ConfigFields(); f.set(FieldKey.name, "Persisted"); f.set(FieldKey.server, "h"); f.set(FieldKey.port, 443); f.set(FieldKey.password, "p")
        try await store1.save(TunnelConfiguration(kind: .trojan, fields: f))

        // A fresh store pointed at the same directory should load it.
        let store2 = DefaultConfigurationStore(persistence: persistence, clock: MutableClock())
        let loaded = await store2.allConfigurations()
        XCTAssertEqual(loaded.first?.name, "Persisted")
        try? FileManager.default.removeItem(at: dir)
    }

    func testEventsEmitOnMutation() async throws {
        let store = makeStore()
        let stream = await store.events()
        let received = Task { () -> StoreEvent? in
            for await event in stream { return event }
            return nil
        }
        // Give the observer task a moment to subscribe before mutating.
        try? await Task.sleep(nanoseconds: 20_000_000)
        var f = ConfigFields(); f.set(FieldKey.name, "E"); f.set(FieldKey.server, "h"); f.set(FieldKey.port, 443); f.set(FieldKey.password, "p")
        try await store.save(TunnelConfiguration(kind: .trojan, fields: f))
        let event = await received.value
        XCTAssertEqual(event, .configsChanged)
    }
}
