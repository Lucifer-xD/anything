import Foundation

/// The primary ``ConfigurationStore`` implementation: an `actor` guarding an
/// in-memory snapshot, with optional pluggable persistence and a broadcast
/// change stream. The app injects ``FilePersistence`` (app-group container);
/// tests inject `nil` for a pure in-memory store.
public actor DefaultConfigurationStore: ConfigurationStore {
    private var snapshot: StoreSnapshot
    private let persistence: ConfigPersisting?
    private let clock: DateProviding
    private var observers: [UUID: AsyncStream<StoreEvent>.Continuation] = [:]

    public init(
        persistence: ConfigPersisting? = nil,
        clock: DateProviding = SystemClock(),
        seed: StoreSnapshot? = nil
    ) {
        self.persistence = persistence
        self.clock = clock
        if let loaded = try? persistence?.load() {
            self.snapshot = loaded
        } else if let seed {
            self.snapshot = seed
        } else {
            self.snapshot = StoreSnapshot(folders: ConfigFolder.defaults)
        }
    }

    // MARK: - Configurations

    public func allConfigurations() -> [TunnelConfiguration] { snapshot.configs }

    public func configuration(id: UUID) -> TunnelConfiguration? {
        snapshot.configs.first { $0.id == id }
    }

    public func query(_ query: ConfigQuery) -> [TunnelConfiguration] {
        query.apply(to: snapshot.configs, folders: snapshot.folders)
    }

    @discardableResult
    public func save(_ config: TunnelConfiguration) throws -> TunnelConfiguration {
        var stamped = config
        stamped.metadata.updatedAt = clock.now()
        if let index = snapshot.configs.firstIndex(where: { $0.id == config.id }) {
            snapshot.configs[index] = stamped
        } else {
            stamped.metadata.createdAt = clock.now()
            snapshot.configs.insert(stamped, at: 0)
        }
        try commit(.configsChanged)
        return stamped
    }

    public func delete(id: UUID) throws {
        snapshot.configs.removeAll { $0.id == id }
        try commit(.configsChanged)
    }

    @discardableResult
    public func duplicate(id: UUID) throws -> TunnelConfiguration {
        guard let original = configuration(id: id) else { throw NimbusError.notFound(id: id.uuidString) }
        let copy = original.duplicated(at: clock.now())
        snapshot.configs.insert(copy, at: 0)
        try commit(.configsChanged)
        return copy
    }

    public func setFavorite(_ id: UUID, _ value: Bool) throws {
        try mutate(id) { $0.metadata.isFavorite = value }
    }

    public func setPinned(_ id: UUID, _ value: Bool) throws {
        try mutate(id) { $0.metadata.isPinned = value }
    }

    public func setArchived(_ id: UUID, _ value: Bool) throws {
        try mutate(id) { $0.metadata.isArchived = value }
    }

    public func move(_ id: UUID, toFolder folderID: UUID?) throws {
        let name = folderID.flatMap { fid in snapshot.folders.first { $0.id == fid }?.name } ?? "Personal"
        try mutate(id) {
            $0.metadata.folderID = folderID
            $0.metadata.group = name
        }
    }

    public func recordConnection(_ id: UUID, at date: Date) {
        guard let index = snapshot.configs.firstIndex(where: { $0.id == id }) else { return }
        snapshot.configs[index].metadata.lastConnectedAt = date
        snapshot.configs[index].metadata.sessionCount += 1
        try? commit(.configsChanged)
    }

    public func addTraffic(_ id: UUID, bytes: UInt64) {
        guard let index = snapshot.configs.firstIndex(where: { $0.id == id }) else { return }
        snapshot.configs[index].metadata.trafficBytes &+= bytes
        try? commit(.configsChanged)
    }

    public func importConfigurations(_ configs: [TunnelConfiguration]) throws {
        for config in configs {
            if let index = snapshot.configs.firstIndex(where: { $0.id == config.id }) {
                snapshot.configs[index] = config
            } else {
                snapshot.configs.insert(config, at: 0)
            }
        }
        try commit(.configsChanged)
    }

    // MARK: - Folders

    public func folders() -> [ConfigFolder] { snapshot.folders.sorted { $0.sortIndex < $1.sortIndex } }

    public func saveFolder(_ folder: ConfigFolder) throws {
        if let index = snapshot.folders.firstIndex(where: { $0.id == folder.id }) {
            snapshot.folders[index] = folder
        } else {
            snapshot.folders.append(folder)
        }
        try commit(.foldersChanged)
    }

    public func deleteFolder(id: UUID) throws {
        snapshot.folders.removeAll { $0.id == id }
        // Orphaned configs fall back to ungrouped.
        for index in snapshot.configs.indices where snapshot.configs[index].metadata.folderID == id {
            snapshot.configs[index].metadata.folderID = nil
        }
        try commit(.foldersChanged)
    }

    // MARK: - Subscriptions

    public func subscriptions() -> [Subscription] { snapshot.subscriptions }

    public func saveSubscription(_ subscription: Subscription) throws {
        if let index = snapshot.subscriptions.firstIndex(where: { $0.id == subscription.id }) {
            snapshot.subscriptions[index] = subscription
        } else {
            snapshot.subscriptions.append(subscription)
        }
        try commit(.subscriptionsChanged)
    }

    public func deleteSubscription(id: UUID) throws {
        snapshot.subscriptions.removeAll { $0.id == id }
        // Remove nodes that belonged to it.
        snapshot.configs.removeAll { $0.metadata.subscriptionID == id }
        try commit(.subscriptionsChanged)
    }

    // MARK: - Observation

    public func events() -> AsyncStream<StoreEvent> {
        AsyncStream { continuation in
            let id = UUID()
            observers[id] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeObserver(id) }
            }
        }
    }

    private func removeObserver(_ id: UUID) { observers[id] = nil }

    // MARK: - Internals

    private func mutate(_ id: UUID, _ transform: (inout TunnelConfiguration) -> Void) throws {
        guard let index = snapshot.configs.firstIndex(where: { $0.id == id }) else {
            throw NimbusError.notFound(id: id.uuidString)
        }
        transform(&snapshot.configs[index])
        snapshot.configs[index].metadata.updatedAt = clock.now()
        try commit(.configsChanged)
    }

    private func commit(_ event: StoreEvent) throws {
        if let persistence {
            try persistence.persist(snapshot)
        }
        for continuation in observers.values { continuation.yield(event) }
    }
}
