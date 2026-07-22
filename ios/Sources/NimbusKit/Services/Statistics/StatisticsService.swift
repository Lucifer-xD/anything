import Foundation

/// Records connection sessions and answers the Statistics screens. Persists
/// session history via the same ``ConfigPersisting``-style pattern (a small JSON
/// file), and exposes aggregations through ``UsageAggregator``.
public actor StatisticsService {
    private var sessions: [SessionRecord]
    private var openSession: SessionRecord?
    private let clock: DateProviding
    private let url: URL?

    public init(clock: DateProviding = SystemClock(), fileURL: URL? = nil, seed: [SessionRecord] = []) {
        self.clock = clock
        self.url = fileURL
        if let url, let data = try? Data(contentsOf: url),
           let decoded = try? Self.decoder.decode([SessionRecord].self, from: data) {
            self.sessions = decoded
        } else {
            self.sessions = seed
        }
    }

    // MARK: Recording

    /// Begin a session for a configuration. Returns the new session id.
    @discardableResult
    public func beginSession(config: TunnelConfiguration) -> UUID {
        let record = SessionRecord(
            configID: config.id,
            configName: config.name,
            kind: config.kind,
            serverHost: config.host,
            startedAt: clock.now()
        )
        openSession = record
        return record.id
    }

    /// Update the in-flight session's live counters.
    public func updateOpenSession(rxBytes: UInt64, txBytes: UInt64, latencyMillis: Int?) {
        guard var open = openSession else { return }
        open.rxBytes = rxBytes
        open.txBytes = txBytes
        if let latencyMillis { open.averageLatencyMillis = latencyMillis }
        openSession = open
    }

    /// Finalize the open session and append it to history.
    public func endSession(failureReason: String? = nil) {
        guard var open = openSession else { return }
        open.endedAt = clock.now()
        open.failureReason = failureReason
        sessions.append(open)
        openSession = nil
        persist()
    }

    // MARK: Queries

    public func allSessions() -> [SessionRecord] { sessions.sorted { $0.startedAt > $1.startedAt } }
    public func summary() -> UsageSummary { UsageAggregator.summary(sessions) }
    public func buckets(_ period: UsagePeriod) -> [UsageBucket] { UsageAggregator.buckets(sessions, period: period) }
    public func protocolUsage() -> [UsageSlice] { UsageAggregator.byProtocol(sessions) }
    public func serverUsage() -> [UsageSlice] { UsageAggregator.byServer(sessions) }

    /// Live totals including the in-flight session (for the dashboard).
    public func liveSummary() -> UsageSummary {
        var all = sessions
        if let open = openSession { all.append(open) }
        return UsageAggregator.summary(all)
    }

    public func clearHistory() {
        sessions.removeAll()
        persist()
    }

    // MARK: Persistence

    private func persist() {
        guard let url else { return }
        if let data = try? Self.encoder.encode(sessions) {
            try? data.write(to: url, options: [.atomic])
        }
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601; return e
    }()
    private static let decoder: JSONDecoder = {
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601; return d
    }()
}
