import SwiftUI
import Combine
import NimbusKit

/// The bottom tab destinations (matching the design's tab bar).
public enum AppTab: String, CaseIterable, Identifiable {
    case library, subscriptions, tools, settings
    public var id: String { rawValue }
    var title: String {
        switch self {
        case .library: return "Configs"
        case .subscriptions: return "Subs"
        case .tools: return "Tools"
        case .settings: return "Settings"
        }
    }
    var systemImage: String {
        switch self {
        case .library: return "square.stack.3d.up"
        case .subscriptions: return "arrow.triangle.2.circlepath"
        case .tools: return "wrench.and.screwdriver"
        case .settings: return "gearshape"
        }
    }
}

/// User-facing settings toggles (persisted). Mirrors the design's `tog` map.
public struct AppSettings: Codable, Equatable {
    public var autoConnect = true
    public var killSwitch = true
    public var splitTunnel = false
    public var doh = true
    public var ipv6 = false
    public var tunMode = false
    public var haptics = true
    public var faceID = true
    public var appLock = false
    public var autoUpdateSubscriptions = true
    public var defaultProtocol: ProtocolKind = .reality
    public var dns = DNSSettings()
    public var language = "English"
}

/// The single SwiftUI source of truth. It bridges NimbusKit's actors to
/// `@Published` state (mirroring the imported design's one-component model) and
/// exposes intent methods the screens call. All actor access is funnelled here
/// so views stay declarative and free of concurrency plumbing.
@MainActor
public final class AppModel: ObservableObject {
    // Appearance
    @Published public var theme: AppTheme { didSet { persistAppearance() } }
    @Published public var accent: AppAccent { didSet { persistAppearance() } }
    public var palette: NimbusPalette { NimbusPalette(theme: theme, accent: accent) }

    // Navigation
    @Published public var tab: AppTab = .library
    @Published public var hasCompletedOnboarding: Bool
    @Published public var isLocked: Bool = false

    // Library
    @Published public private(set) var configs: [TunnelConfiguration] = []
    @Published public private(set) var folders: [ConfigFolder] = []
    @Published public private(set) var subscriptions: [Subscription] = []
    @Published public private(set) var servers: [Server] = []
    @Published public var filter: LibraryFilter = .all
    @Published public var searchText: String = ""
    @Published public var sort: ConfigSort = .recent

    // Connection
    @Published public private(set) var connection: ConnectionState = .disconnected
    @Published public private(set) var activeConfigID: UUID?
    @Published public private(set) var elapsedSeconds: Int = 0
    @Published public private(set) var sample: TrafficSample = TrafficSample()

    // Logs & stats
    @Published public private(set) var logs: [LogEntry] = []
    @Published public var logFilter: LogFilter = .all
    @Published public private(set) var statsSummary: UsageSummary = .empty
    @Published public private(set) var sessions: [SessionRecord] = []

    // Settings & sync
    @Published public var settings: AppSettings { didSet { persistSettings() } }
    @Published public private(set) var syncAccount: SyncAccount?
    @Published public var isRefreshingSubscriptions = false

    public let services: AppServices
    private var cancellables = Set<AnyCancellable>()
    private var sessionStart: Date?
    private let defaults = UserDefaults.standard

    public init(services: AppServices) {
        self.services = services
        self.theme = AppModel.loadEnum("nimbus.theme", default: AppTheme.dark)
        self.accent = AppModel.loadEnum("nimbus.accent", default: AppAccent.blue)
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "nimbus.onboarded")
        if let data = UserDefaults.standard.data(forKey: "nimbus.settings"),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            self.settings = decoded
        } else {
            self.settings = AppSettings()
        }
    }

    /// Kick off observation of the store, tunnel and a 1 Hz timer. Called from
    /// the root `.task`.
    public func start() async {
        await reloadLibrary()
        await reloadLogs()
        await reloadStats()
        syncAccount = await services.sync.account()

        // Store changes → refresh library.
        Task { [weak self] in
            guard let self else { return }
            for await _ in await services.store.events() { await self.reloadLibrary() }
        }
        // Tunnel events → connection state / traffic / logs.
        Task { [weak self] in
            guard let self else { return }
            for await event in await services.tunnel.events() {
                await self.handle(event)
            }
        }
        // 1 Hz timer for the session clock.
        Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
            .store(in: &cancellables)
    }

    // MARK: - Derived library

    public var visibleConfigs: [TunnelConfiguration] {
        ConfigQuery(searchText: searchText, filter: filter, sort: sort).apply(to: configs, folders: folders)
    }

    public var activeConfig: TunnelConfiguration? {
        configs.first { $0.id == activeConfigID } ?? configs.first
    }

    public var filterChips: [LibraryFilterChip] {
        var chips: [LibraryFilterChip] = [
            .init(filter: .all, title: "All"),
            .init(filter: .favorites, title: "Favorites"),
            .init(filter: .pinned, title: "Pinned"),
        ]
        chips += folders.map { .init(filter: .group($0.name), title: $0.name) }
        return chips
    }

    // MARK: - Intents: connection

    public func connect(_ id: UUID) {
        Task { try? await services.tunnel.connect(configID: id); await MainActor.run { self.sessionStart = Date() } }
    }
    public func disconnect() { Task { await services.tunnel.disconnect() } }
    public func toggle(_ id: UUID) { Task { try? await services.tunnel.toggle(configID: id) } }
    public func quickConnect() { Task { try? await services.tunnel.quickConnect() } }

    // MARK: - Intents: library

    public func save(_ config: TunnelConfiguration) { Task { try? await services.store.save(config) } }
    public func delete(_ id: UUID) { Task { try? await services.store.delete(id: id) } }
    public func duplicate(_ id: UUID) { Task { try? await services.store.duplicate(id: id) } }
    public func setFavorite(_ id: UUID, _ value: Bool) { Task { try? await services.store.setFavorite(id, value) } }
    public func setPinned(_ id: UUID, _ value: Bool) { Task { try? await services.store.setPinned(id, value) } }
    public func setArchived(_ id: UUID, _ value: Bool) { Task { try? await services.store.setArchived(id, value) } }
    public func move(_ id: UUID, toFolder folderID: UUID?) { Task { try? await services.store.move(id, toFolder: folderID) } }

    /// Import raw text (clipboard / URL body / file contents / QR payload).
    @discardableResult
    public func importText(_ text: String, source: ConfigSource) async -> ImportResult {
        let result = services.importer.import(text, source: source)
        if !result.isEmpty { try? await services.store.importConfigurations(result.configs) }
        return result
    }

    public func shareLink(for config: TunnelConfiguration) -> String? {
        services.exporter.shareLink(for: config)
    }
    public func qrPayload(for config: TunnelConfiguration) -> String? {
        try? services.exporter.qrPayload(for: config)
    }
    public func exportBundle() -> Data? {
        try? services.exporter.bundle(configs: configs, folders: folders)
    }

    // MARK: - Intents: subscriptions

    public func refreshSubscriptions() {
        Task {
            await MainActor.run { self.isRefreshingSubscriptions = true }
            await services.subscriptions.refreshAll(force: true)
            await MainActor.run { self.isRefreshingSubscriptions = false }
        }
    }
    public func addSubscription(_ sub: Subscription) { Task { try? await services.store.saveSubscription(sub) } }
    public func deleteSubscription(_ id: UUID) { Task { try? await services.store.deleteSubscription(id: id) } }

    // MARK: - Intents: logs & stats

    public func clearLogs() { Task { await services.logs.clear(); await reloadLogs() } }
    public func exportLogs() async -> String { await services.logs.exportText(logFilter) }
    public var filteredLogs: [LogEntry] { logs.filter { logFilter.matches($0.level) } }

    // MARK: - Intents: appearance & onboarding

    public func cycleTheme() { theme = theme.next }
    public func completeOnboarding() {
        hasCompletedOnboarding = true
        defaults.set(true, forKey: "nimbus.onboarded")
    }

    // MARK: - Intents: sync

    public func signIn(email: String, passphrase: String) {
        Task {
            let account = try? await services.sync.signIn(email: email, passphrase: passphrase, e2eEnabled: true)
            await MainActor.run { self.syncAccount = account }
        }
    }
    public func backupNow() {
        Task { try? await services.sync.backup(StoreSnapshot(configs: configs, folders: folders, subscriptions: subscriptions)) }
    }

    // MARK: - Reloads

    private func reloadLibrary() async {
        configs = await services.store.allConfigurations()
        folders = await services.store.folders()
        subscriptions = await services.store.subscriptions()
        servers = await services.servers.all()
    }
    private func reloadLogs() async { logs = await services.logs.all() }
    private func reloadStats() async {
        statsSummary = await services.statistics.summary()
        sessions = await services.statistics.allSessions()
    }

    // MARK: - Event handling

    private func handle(_ event: TunnelEvent) async {
        switch event {
        case let .state(state):
            connection = state
            activeConfigID = await services.tunnel.activeConfigID
            if state == .connected, sessionStart == nil { sessionStart = Date() }
            if case .disconnected = state { sessionStart = nil; elapsedSeconds = 0; sample = TrafficSample() ; await reloadStats() }
        case let .traffic(sample):
            self.sample = sample
        case let .log(entry):
            logs.append(entry)
            if logs.count > 2000 { logs.removeFirst(logs.count - 2000) }
        }
    }

    private func tick() {
        guard connection.isActive, let start = sessionStart else { return }
        elapsedSeconds = max(0, Int(Date().timeIntervalSince(start)))
    }

    // MARK: - Persistence

    private func persistAppearance() {
        defaults.set(theme.rawValue, forKey: "nimbus.theme")
        defaults.set(accent.rawValue, forKey: "nimbus.accent")
    }
    private func persistSettings() {
        if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: "nimbus.settings") }
    }
    private static func loadEnum<T: RawRepresentable>(_ key: String, default fallback: T) -> T where T.RawValue == String {
        guard let raw = UserDefaults.standard.string(forKey: key), let value = T(rawValue: raw) else { return fallback }
        return value
    }
}

/// A filter chip descriptor for the library header.
public struct LibraryFilterChip: Identifiable {
    public let filter: LibraryFilter
    public let title: String
    public var id: String { title }
}
