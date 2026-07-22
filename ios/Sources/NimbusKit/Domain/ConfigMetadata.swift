import Foundation

/// Where a configuration originally came from — surfaced as a small tag and used
/// by sync/analytics.
public enum ConfigSource: String, Codable, CaseIterable, Sendable {
    case manual
    case template
    case qr
    case clipboard
    case url
    case file
    case subscription
    case cloud

    public var displayName: String {
        switch self {
        case .manual: return "Created manually"
        case .template: return "From template"
        case .qr: return "Scanned QR"
        case .clipboard: return "Pasted"
        case .url: return "Imported from URL"
        case .file: return "Imported file"
        case .subscription: return "Subscription"
        case .cloud: return "Cloud sync"
        }
    }
}

/// Library metadata that lives *around* a configuration's protocol fields:
/// organization (folder, tags), user flags (favorite, pinned, archived),
/// provenance, and observed runtime facts (latency, traffic, timestamps).
public struct ConfigMetadata: Codable, Equatable, Sendable {
    public var folderID: UUID?
    /// Display group name, kept in sync with the folder for the library chips.
    public var group: String
    public var tags: [String]
    public var isFavorite: Bool
    public var isPinned: Bool
    public var isArchived: Bool
    /// Optional custom color tag (hex) for the card accent.
    public var colorTag: String?
    public var source: ConfigSource
    /// Subscription this config belongs to, if imported from one.
    public var subscriptionID: UUID?
    public var notes: String?

    public var createdAt: Date
    public var updatedAt: Date
    public var lastConnectedAt: Date?
    public var expiresAt: Date?

    /// Most recent latency probe (ms), if any.
    public var latencyMillis: Int?
    /// Lifetime traffic attributed to this config, in bytes.
    public var trafficBytes: UInt64
    /// Number of successful sessions (for the "reliability" stats row).
    public var sessionCount: Int

    public init(
        folderID: UUID? = nil,
        group: String = "Personal",
        tags: [String] = [],
        isFavorite: Bool = false,
        isPinned: Bool = false,
        isArchived: Bool = false,
        colorTag: String? = nil,
        source: ConfigSource = .manual,
        subscriptionID: UUID? = nil,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        lastConnectedAt: Date? = nil,
        expiresAt: Date? = nil,
        latencyMillis: Int? = nil,
        trafficBytes: UInt64 = 0,
        sessionCount: Int = 0
    ) {
        self.folderID = folderID
        self.group = group
        self.tags = tags
        self.isFavorite = isFavorite
        self.isPinned = isPinned
        self.isArchived = isArchived
        self.colorTag = colorTag
        self.source = source
        self.subscriptionID = subscriptionID
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastConnectedAt = lastConnectedAt
        self.expiresAt = expiresAt
        self.latencyMillis = latencyMillis
        self.trafficBytes = trafficBytes
        self.sessionCount = sessionCount
    }
}
