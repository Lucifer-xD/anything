import Foundation

/// Health of a server endpoint from the most recent probe.
public enum ServerHealth: String, Codable, Sendable {
    case unknown
    case healthy
    case degraded
    case unreachable

    public var tintHex: String {
        switch self {
        case .unknown: return "#8E8E93"
        case .healthy: return "#30D158"
        case .degraded: return "#FF9F0A"
        case .unreachable: return "#FF453A"
        }
    }
}

/// A reusable server endpoint that one or more configurations point at. Servers
/// carry the geo/category metadata used by the Server Management screen
/// (categories, favorites, tags, latency testing, health checks, recents).
public struct Server: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var host: String
    public var port: Int
    public var countryCode: String     // ISO-3166 alpha-2, e.g. "DE"
    public var city: String?
    public var category: String        // e.g. "Streaming", "Gaming", "Free"
    public var tags: [String]
    public var isFavorite: Bool
    public var latencyMillis: Int?
    public var health: ServerHealth
    public var lastCheckedAt: Date?
    public var lastUsedAt: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        host: String,
        port: Int,
        countryCode: String,
        city: String? = nil,
        category: String = "General",
        tags: [String] = [],
        isFavorite: Bool = false,
        latencyMillis: Int? = nil,
        health: ServerHealth = .unknown,
        lastCheckedAt: Date? = nil,
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.countryCode = countryCode
        self.city = city
        self.category = category
        self.tags = tags
        self.isFavorite = isFavorite
        self.latencyMillis = latencyMillis
        self.health = health
        self.lastCheckedAt = lastCheckedAt
        self.lastUsedAt = lastUsedAt
    }

    /// Flag emoji derived from the ISO country code.
    public var flagEmoji: String {
        countryCode.uppercased().unicodeScalars.reduce(into: "") { acc, scalar in
            if let flag = Unicode.Scalar(127_397 + scalar.value) { acc.unicodeScalars.append(flag) }
        }
    }
}

/// How the Server Management list is ordered.
public enum ServerSort: String, CaseIterable, Sendable {
    case latency = "Latency"
    case name = "Name"
    case country = "Country"
    case recent = "Recently used"
}
