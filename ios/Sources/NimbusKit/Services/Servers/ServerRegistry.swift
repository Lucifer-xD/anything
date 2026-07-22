import Foundation

/// Measures latency to an endpoint. The simulated implementation delegates to
/// the tunnel engine; a production build would use `Network.framework` TCP
/// connect timing.
public protocol LatencyProbing: Sendable {
    func latency(host: String, port: Int) async -> Int?
}

/// Adapts any ``TunnelEngine`` into a ``LatencyProbing`` source.
public struct EngineLatencyProbe: LatencyProbing {
    private let engine: TunnelEngine
    public init(engine: TunnelEngine) { self.engine = engine }
    public func latency(host: String, port: Int) async -> Int? {
        await engine.probeLatency(host: host, port: port)
    }
}

/// The Server Management data source: categories, favorites, search, sorting,
/// recently-used, custom tags, latency testing and health checks.
public actor ServerRegistry {
    private var servers: [Server]
    private let probe: LatencyProbing
    private let clock: DateProviding

    public init(servers: [Server] = [], probe: LatencyProbing, clock: DateProviding = SystemClock()) {
        self.servers = servers
        self.probe = probe
        self.clock = clock
    }

    public func all() -> [Server] { servers }

    public func categories() -> [String] {
        Array(Set(servers.map(\.category))).sorted()
    }

    public func save(_ server: Server) {
        if let index = servers.firstIndex(where: { $0.id == server.id }) { servers[index] = server }
        else { servers.append(server) }
    }

    public func delete(id: UUID) { servers.removeAll { $0.id == id } }

    public func setFavorite(_ id: UUID, _ value: Bool) {
        guard let index = servers.firstIndex(where: { $0.id == id }) else { return }
        servers[index].isFavorite = value
    }

    public func markUsed(_ id: UUID) {
        guard let index = servers.firstIndex(where: { $0.id == id }) else { return }
        servers[index].lastUsedAt = clock.now()
    }

    /// Filter + sort for the list UI.
    public func list(category: String? = nil, favoritesOnly: Bool = false, search: String = "", sort: ServerSort = .latency) -> [Server] {
        let needle = search.trimmingCharacters(in: .whitespaces).lowercased()
        var result = servers.filter { server in
            if favoritesOnly && !server.isFavorite { return false }
            if let category, server.category != category { return false }
            guard !needle.isEmpty else { return true }
            return "\(server.name) \(server.host) \(server.city ?? "") \(server.countryCode) \(server.tags.joined(separator: " "))"
                .lowercased().contains(needle)
        }
        result.sort { lhs, rhs in
            switch sort {
            case .latency: return (lhs.latencyMillis ?? .max) < (rhs.latencyMillis ?? .max)
            case .name: return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            case .country: return lhs.countryCode < rhs.countryCode
            case .recent: return (lhs.lastUsedAt ?? .distantPast) > (rhs.lastUsedAt ?? .distantPast)
            }
        }
        return result
    }

    /// Probe latency for every server concurrently and update health.
    public func refreshLatencies() async {
        await withTaskGroup(of: (UUID, Int?).self) { group in
            for server in servers {
                let host = server.host, port = server.port, id = server.id
                group.addTask { [probe] in (id, await probe.latency(host: host, port: port)) }
            }
            for await (id, latency) in group {
                guard let index = servers.firstIndex(where: { $0.id == id }) else { continue }
                servers[index].latencyMillis = latency
                servers[index].lastCheckedAt = clock.now()
                servers[index].health = Self.health(for: latency)
            }
        }
    }

    /// Probe a single server (the "test" button).
    @discardableResult
    public func test(id: UUID) async -> Int? {
        guard let server = servers.first(where: { $0.id == id }) else { return nil }
        let latency = await probe.latency(host: server.host, port: server.port)
        if let index = servers.firstIndex(where: { $0.id == id }) {
            servers[index].latencyMillis = latency
            servers[index].lastCheckedAt = clock.now()
            servers[index].health = Self.health(for: latency)
        }
        return latency
    }

    private static func health(for latency: Int?) -> ServerHealth {
        guard let latency else { return .unreachable }
        switch latency {
        case ..<80: return .healthy
        case 80..<180: return .degraded
        default: return .degraded
        }
    }
}
