import Foundation

/// Injectable platform pieces the core can't provide itself (they need Apple
/// frameworks). Defaults are simulated/in-memory so the whole graph builds and
/// runs on Linux and in tests; the app overrides them with real implementations
/// (Packet Tunnel engine, `URLSession` fetcher, LocalAuthentication, CryptoKit).
public struct AppEnvironmentConfiguration: @unchecked Sendable {
    /// Directory for persisted state (store.json, sessions.json). `nil` ⇒ memory.
    public var storageDirectory: URL?
    /// Seed sample content on a fresh (empty) install.
    public var seedSampleData: Bool
    public var engine: TunnelEngine
    public var subscriptionFetcher: SubscriptionFetching
    public var appLockAuthenticator: AppLockAuthenticating
    /// Cipher used when E2E sync is enabled.
    public var syncCipher: ConfigurationCipher
    /// Secret storage (Keychain in the app, in-memory in tests).
    public var secureStore: SecureStore
    public var clock: DateProviding

    public init(
        storageDirectory: URL? = nil,
        seedSampleData: Bool = true,
        engine: TunnelEngine = SimulatedTunnelEngine(),
        subscriptionFetcher: SubscriptionFetching = StubSubscriptionFetcher(),
        appLockAuthenticator: AppLockAuthenticating = AlwaysAllowAppLock(),
        syncCipher: ConfigurationCipher = PassthroughCipher(),
        secureStore: SecureStore = InMemorySecureStore(),
        clock: DateProviding = SystemClock()
    ) {
        self.storageDirectory = storageDirectory
        self.seedSampleData = seedSampleData
        self.engine = engine
        self.subscriptionFetcher = subscriptionFetcher
        self.appLockAuthenticator = appLockAuthenticator
        self.syncCipher = syncCipher
        self.secureStore = secureStore
        self.clock = clock
    }
}

/// The composition root. Assembles every core service and exposes them to the
/// app's view models. This is the single place wiring happens — the UI layer
/// depends on these abstractions, never constructs them.
public final class AppServices: @unchecked Sendable {
    public let store: ConfigurationStore
    public let tunnel: TunnelController
    public let logs: LogStore
    public let statistics: StatisticsService
    public let servers: ServerRegistry
    public let sync: CloudSyncService
    public let subscriptions: SubscriptionService
    public let importer: ConfigImporter
    public let exporter: ConfigExporter
    public let secureStore: SecureStore
    public let appLock: AppLockController
    public let registry: ProtocolRegistry
    public let clock: DateProviding

    public init(configuration: AppEnvironmentConfiguration = AppEnvironmentConfiguration()) {
        let clock = configuration.clock
        self.clock = clock
        self.registry = .shared

        // Persistence
        let persistence = configuration.storageDirectory.map { FilePersistence(directory: $0) }
        let seed = configuration.seedSampleData ? SampleData.snapshot : nil
        let store = DefaultConfigurationStore(persistence: persistence, clock: clock, seed: seed)
        self.store = store

        let statsURL = configuration.storageDirectory?.appendingPathComponent("sessions.json")
        self.statistics = StatisticsService(clock: clock, fileURL: statsURL)

        let logs = LogStore(seed: configuration.seedSampleData ? SampleData.logs : [])
        self.logs = logs

        self.tunnel = TunnelController(
            engine: configuration.engine,
            store: store,
            logStore: logs,
            statistics: statistics,
            registry: registry,
            clock: clock
        )

        self.servers = ServerRegistry(
            servers: configuration.seedSampleData ? SampleData.servers : [],
            probe: EngineLatencyProbe(engine: configuration.engine),
            clock: clock
        )

        self.sync = LocalMockCloudSyncService(clock: clock, encryptingCipher: configuration.syncCipher)

        self.importer = ConfigImporter(registry: registry)
        self.exporter = ConfigExporter(registry: registry)
        self.subscriptions = SubscriptionService(
            store: store,
            fetcher: configuration.subscriptionFetcher,
            importer: importer,
            clock: clock
        )

        self.secureStore = configuration.secureStore
        self.appLock = AppLockController(authenticator: configuration.appLockAuthenticator, enabled: false)
    }

    /// A fully in-memory, seeded graph for previews and tests.
    public static func makeSimulated(seeded: Bool = true) -> AppServices {
        AppServices(configuration: AppEnvironmentConfiguration(seedSampleData: seeded))
    }
}
