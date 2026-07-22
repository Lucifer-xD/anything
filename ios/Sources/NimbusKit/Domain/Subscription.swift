import Foundation

/// A remote source of configurations (a "subscription" in HTTP-Injector / v2ray
/// parlance): a URL that returns a base64 list of share-links, refreshed on a
/// schedule. Nimbus tracks the parsed node count, refresh cadence, expiry and
/// traffic quota surfaced by the provider.
public struct Subscription: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var url: URL
    /// Folder new nodes land in.
    public var folderID: UUID?
    public var autoUpdate: Bool
    /// Refresh interval in seconds (default 6h, matching the design).
    public var refreshInterval: TimeInterval
    public var lastUpdated: Date?
    public var nodeCount: Int
    /// Provider-reported expiry, if any (from `subscription-userinfo` header).
    public var expiresAt: Date?
    /// Bytes used / total, when the provider advertises a quota.
    public var usedBytes: UInt64?
    public var totalBytes: UInt64?
    public var tintHex: String

    public init(
        id: UUID = UUID(),
        name: String,
        url: URL,
        folderID: UUID? = nil,
        autoUpdate: Bool = true,
        refreshInterval: TimeInterval = 6 * 60 * 60,
        lastUpdated: Date? = nil,
        nodeCount: Int = 0,
        expiresAt: Date? = nil,
        usedBytes: UInt64? = nil,
        totalBytes: UInt64? = nil,
        tintHex: String = "#0A84FF"
    ) {
        self.id = id
        self.name = name
        self.url = url
        self.folderID = folderID
        self.autoUpdate = autoUpdate
        self.refreshInterval = refreshInterval
        self.lastUpdated = lastUpdated
        self.nodeCount = nodeCount
        self.expiresAt = expiresAt
        self.usedBytes = usedBytes
        self.totalBytes = totalBytes
        self.tintHex = tintHex
    }

    /// Whether a refresh is due given `now`.
    public func needsRefresh(now: Date) -> Bool {
        guard autoUpdate else { return false }
        guard let lastUpdated else { return true }
        return now.timeIntervalSince(lastUpdated) >= refreshInterval
    }
}
