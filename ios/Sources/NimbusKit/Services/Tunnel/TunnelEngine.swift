import Foundation

/// Everything the engine emits during a session: state transitions, throughput
/// samples, and structured log lines.
public enum TunnelEvent: Sendable, Equatable {
    case state(ConnectionState)
    case traffic(TrafficSample)
    case log(LogEntry)
}

/// The boundary between Nimbus and whatever actually carries packets. In this
/// build the only implementation is ``SimulatedTunnelEngine``; in production a
/// second implementation drives the Packet Tunnel extension (WireGuardKit /
/// Xray / sing-box / SSH) — see `Tunnel/TunnelBridge.swift` and
/// `docs/RESEARCH.md §3`. Everything above this protocol is fully real.
public protocol TunnelEngine: Sendable {
    /// Begin a session for `plan`. The returned stream emits until the session
    /// ends (either by ``stop()`` or a failure).
    func start(_ plan: SessionPlan) async -> AsyncStream<TunnelEvent>
    /// Tear the session down.
    func stop() async
    /// A one-shot latency probe to `host` (ms), used by the servers screen and
    /// the "test" actions. Returns `nil` if unreachable.
    func probeLatency(host: String, port: Int) async -> Int?
}
