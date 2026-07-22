import Foundation

/// Provider-reported quota/expiry, parsed from the `subscription-userinfo`
/// response header (`upload=…; download=…; total=…; expire=…`).
public struct SubscriptionUserInfo: Equatable, Sendable {
    public var uploadBytes: UInt64?
    public var downloadBytes: UInt64?
    public var totalBytes: UInt64?
    public var expiresAt: Date?
}

/// Fetches a subscription URL. Injected so the core stays network-free and
/// testable; the app provides a `URLSession`-backed implementation.
public protocol SubscriptionFetching: Sendable {
    /// Returns the raw body (base64 blob or newline links) and any user-info header.
    func fetch(_ url: URL) async throws -> (body: String, userInfo: SubscriptionUserInfo?)
}

/// Refreshes subscriptions: fetch → parse nodes → tag them to the subscription
/// → import into the store, updating node count / expiry / quota.
public actor SubscriptionService {
    private let store: ConfigurationStore
    private let fetcher: SubscriptionFetching
    private let importer: ConfigImporter
    private let clock: DateProviding

    public init(store: ConfigurationStore, fetcher: SubscriptionFetching, importer: ConfigImporter = ConfigImporter(), clock: DateProviding = SystemClock()) {
        self.store = store
        self.fetcher = fetcher
        self.importer = importer
        self.clock = clock
    }

    /// Refresh a single subscription; returns the number of nodes imported.
    @discardableResult
    public func refresh(_ subscription: Subscription) async throws -> Int {
        let (body, userInfo) = try await fetcher.fetch(subscription.url)
        let result = importer.import(body, source: .subscription)
        guard !result.isEmpty else {
            throw NimbusError.emptyImport(reason: "subscription returned no nodes")
        }
        let tagged = result.configs.map { config -> TunnelConfiguration in
            var copy = config
            copy.metadata.subscriptionID = subscription.id
            copy.metadata.folderID = subscription.folderID
            copy.metadata.group = "Subscriptions"
            copy.metadata.expiresAt = subscription.expiresAt
            return copy
        }
        try await store.importConfigurations(tagged)

        var updated = subscription
        updated.lastUpdated = clock.now()
        updated.nodeCount = tagged.count
        if let userInfo {
            if let up = userInfo.uploadBytes, let down = userInfo.downloadBytes {
                updated.usedBytes = up &+ down
            } else {
                updated.usedBytes = userInfo.downloadBytes ?? userInfo.uploadBytes
            }
            updated.totalBytes = userInfo.totalBytes
            updated.expiresAt = userInfo.expiresAt ?? updated.expiresAt
        }
        try await store.saveSubscription(updated)
        return tagged.count
    }

    /// Refresh every subscription that is due (or all when `force`).
    public func refreshAll(force: Bool = false) async {
        let subs = await store.subscriptions()
        for subscription in subs where force || subscription.needsRefresh(now: clock.now()) {
            _ = try? await refresh(subscription)
        }
    }

    /// Parse a `subscription-userinfo` header value.
    public nonisolated static func parseUserInfo(_ header: String) -> SubscriptionUserInfo {
        var info = SubscriptionUserInfo()
        for pair in header.split(separator: ";") {
            let kv = pair.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard kv.count == 2 else { continue }
            switch kv[0].lowercased() {
            case "upload": info.uploadBytes = UInt64(kv[1])
            case "download": info.downloadBytes = UInt64(kv[1])
            case "total": info.totalBytes = UInt64(kv[1])
            case "expire": if let ts = TimeInterval(kv[1]) { info.expiresAt = Date(timeIntervalSince1970: ts) }
            default: break
            }
        }
        return info
    }
}
