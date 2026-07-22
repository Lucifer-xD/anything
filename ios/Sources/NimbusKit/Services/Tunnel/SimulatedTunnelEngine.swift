import Foundation

/// A fully-working *simulated* engine. It reproduces the real connection
/// lifecycle — handshake logs, `connecting → connected`, ~1 Hz throughput
/// samples, graceful teardown — so the entire app (dashboard timer, live
/// bandwidth, logs, statistics) is exercised end-to-end without a native core.
///
/// Swapping in the production engine is a one-line change in ``AppServices``.
public actor SimulatedTunnelEngine: TunnelEngine {
    private var runner: Task<Void, Never>?
    private var continuation: AsyncStream<TunnelEvent>.Continuation?
    private let clock: DateProviding
    /// Speeds are scaled by this so tests can run the loop fast.
    private let tickNanos: UInt64

    public init(clock: DateProviding = SystemClock(), tickNanos: UInt64 = 1_000_000_000) {
        self.clock = clock
        self.tickNanos = tickNanos
    }

    public func start(_ plan: SessionPlan) -> AsyncStream<TunnelEvent> {
        teardown(finalStates: false)
        let (stream, cont) = AsyncStream<TunnelEvent>.makeStream()
        continuation = cont
        runner = Task { [weak self] in await self?.run(plan) }
        return stream
    }

    public func stop() {
        guard continuation != nil else { return }
        emit(.log(LogEntry(level: .info, category: "tunnel", message: "Stopping tunnel — user requested")))
        emit(.state(.disconnecting))
        emit(.log(LogEntry(level: .ok, category: "tunnel", message: "Tunnel closed")))
        emit(.state(.disconnected))
        teardown(finalStates: true)
    }

    public func probeLatency(host: String, port: Int) async -> Int? {
        try? await Task.sleep(nanoseconds: min(tickNanos / 20, 60_000_000))
        // Deterministic-but-plausible latency derived from the host name.
        let base = abs(host.hashValue % 120) + 12
        return base
    }

    // MARK: - Simulation

    private func run(_ plan: SessionPlan) async {
        emit(.state(.connecting))
        let steps: [(LogLevel, String)] = [
            (.info, "Parsing config \"\(plan.displayName)\""),
            (.info, "Selected protocol \(plan.kind.metadata.displayName)"),
            (.info, "Resolving \(plan.host):\(plan.port)"),
            (.ok,   "TLS handshake — SNI \(plan.parameters[FieldKey.sni] ?? plan.host)"),
            (.ok,   "\(plan.core.rawValue) authenticated"),
            (.info, "DNS set to \(plan.dnsServers.joined(separator: ", "))"),
            (.ok,   "Kill switch armed"),
            (.info, "Route \(plan.includedRoutes.first ?? "0.0.0.0/0") via tunnel"),
        ]
        for (level, message) in steps {
            if Task.isCancelled { return }
            emit(.log(LogEntry(timestamp: clock.now(), level: level, message: message)))
            try? await Task.sleep(nanoseconds: tickNanos / 8)
        }
        if Task.isCancelled { return }
        emit(.state(.connected))
        emit(.log(LogEntry(timestamp: clock.now(), level: .ok, category: "tunnel", message: "Link established")))

        var rx: UInt64 = 0
        var tx: UInt64 = 0
        var tick = 0
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: tickNanos)
            if Task.isCancelled { return }
            tick += 1
            // Plausible varying throughput (bits/sec).
            let down = Double(60 + (tick * 37 % 180)) * 1_000_000
            let up = Double(20 + (tick * 19 % 60)) * 1_000_000
            rx &+= UInt64(down / 8)
            tx &+= UInt64(up / 8)
            emit(.traffic(TrafficSample(
                rxBytes: rx, txBytes: tx,
                downloadBitsPerSecond: down, uploadBitsPerSecond: up,
                timestamp: clock.now()
            )))
            if tick % 12 == 0 {
                emit(.log(LogEntry(timestamp: clock.now(), level: .info, category: "tunnel",
                                   message: "rx \(ByteFormat.short(rx)) · tx \(ByteFormat.short(tx))")))
            }
        }
    }

    private func emit(_ event: TunnelEvent) { continuation?.yield(event) }

    private func teardown(finalStates: Bool) {
        runner?.cancel()
        runner = nil
        continuation?.finish()
        continuation = nil
    }
}
