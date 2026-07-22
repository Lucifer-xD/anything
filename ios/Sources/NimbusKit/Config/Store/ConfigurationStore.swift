import Foundation

/// A snapshot of everything the store persists. Also the on-disk shape.
public struct StoreSnapshot: Codable, Equatable, Sendable {
    public var configs: [TunnelConfiguration]
    public var folders: [ConfigFolder]
    public var subscriptions: [Subscription]

    public init(configs: [TunnelConfiguration] = [], folders: [ConfigFolder] = [], subscriptions: [Subscription] = []) {
        self.configs = configs
        self.folders = folders
        self.subscriptions = subscriptions
    }
}

/// A mutation notification emitted to observers.
public enum StoreEvent: Equatable, Sendable {
    case configsChanged
    case foldersChanged
    case subscriptionsChanged
}

/// Persistence backend for the store. Injecting this keeps the store pure and
/// testable (tests use no persistence; the app uses ``FilePersistence`` in the
/// shared app-group container).
public protocol ConfigPersisting: Sendable {
    func load() throws -> StoreSnapshot?
    func persist(_ snapshot: StoreSnapshot) throws
}

/// The library's data access contract: configurations, folders and
/// subscriptions, plus a change stream. All async so implementations can be
/// actors or hit disk/network.
public protocol ConfigurationStore: Sendable {
    // Configurations
    func allConfigurations() async -> [TunnelConfiguration]
    func configuration(id: UUID) async -> TunnelConfiguration?
    func query(_ query: ConfigQuery) async -> [TunnelConfiguration]
    @discardableResult func save(_ config: TunnelConfiguration) async throws -> TunnelConfiguration
    func delete(id: UUID) async throws
    @discardableResult func duplicate(id: UUID) async throws -> TunnelConfiguration
    func setFavorite(_ id: UUID, _ value: Bool) async throws
    func setPinned(_ id: UUID, _ value: Bool) async throws
    func setArchived(_ id: UUID, _ value: Bool) async throws
    func move(_ id: UUID, toFolder folderID: UUID?) async throws
    func recordConnection(_ id: UUID, at date: Date) async
    func addTraffic(_ id: UUID, bytes: UInt64) async
    func importConfigurations(_ configs: [TunnelConfiguration]) async throws

    // Folders
    func folders() async -> [ConfigFolder]
    func saveFolder(_ folder: ConfigFolder) async throws
    func deleteFolder(id: UUID) async throws

    // Subscriptions
    func subscriptions() async -> [Subscription]
    func saveSubscription(_ subscription: Subscription) async throws
    func deleteSubscription(id: UUID) async throws

    // Observation
    func events() async -> AsyncStream<StoreEvent>
}
