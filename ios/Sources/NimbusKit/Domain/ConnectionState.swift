import Foundation

/// The tunnel connection lifecycle. Mirrors `NEVPNStatus` but is framework-free
/// so the whole app (and tests) can reason about it without NetworkExtension.
public enum ConnectionState: Equatable, Sendable {
    case disconnected
    case connecting
    case connected
    case reasserting     // re-establishing after a network change
    case disconnecting
    /// Terminal failure with a human-readable reason.
    case failed(reason: String)

    public var isActive: Bool { self == .connected || self == .reasserting }
    public var isBusy: Bool { self == .connecting || self == .disconnecting || self == .reasserting }

    /// Matches the three high-level buckets the dashboard renders.
    public var bucket: Bucket {
        switch self {
        case .disconnected, .failed: return .idle
        case .connecting, .disconnecting, .reasserting: return .connecting
        case .connected: return .connected
        }
    }

    public enum Bucket: String, Sendable { case idle, connecting, connected }

    public var label: String {
        switch self {
        case .disconnected: return "Not connected"
        case .connecting: return "Connecting…"
        case .connected: return "Connected"
        case .reasserting: return "Reconnecting…"
        case .disconnecting: return "Disconnecting…"
        case .failed(let reason): return "Failed — \(reason)"
        }
    }
}

/// A point-in-time throughput sample emitted by the tunnel engine (~1 Hz).
public struct TrafficSample: Equatable, Sendable {
    /// Cumulative bytes received since the session began.
    public var rxBytes: UInt64
    /// Cumulative bytes sent since the session began.
    public var txBytes: UInt64
    /// Instantaneous download rate in bits/sec.
    public var downloadBitsPerSecond: Double
    /// Instantaneous upload rate in bits/sec.
    public var uploadBitsPerSecond: Double
    public var timestamp: Date

    public init(
        rxBytes: UInt64 = 0,
        txBytes: UInt64 = 0,
        downloadBitsPerSecond: Double = 0,
        uploadBitsPerSecond: Double = 0,
        timestamp: Date = Date()
    ) {
        self.rxBytes = rxBytes
        self.txBytes = txBytes
        self.downloadBitsPerSecond = downloadBitsPerSecond
        self.uploadBitsPerSecond = uploadBitsPerSecond
        self.timestamp = timestamp
    }

    public var downloadMbps: Double { downloadBitsPerSecond / 1_000_000 }
    public var uploadMbps: Double { uploadBitsPerSecond / 1_000_000 }
}

/// A completed (or in-progress) connection session, persisted for the History /
/// Statistics screens.
public struct SessionRecord: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var configID: UUID
    public var configName: String
    public var kind: ProtocolKind
    public var serverHost: String
    public var startedAt: Date
    public var endedAt: Date?
    public var rxBytes: UInt64
    public var txBytes: UInt64
    public var averageLatencyMillis: Int?
    /// Set when the session ended abnormally.
    public var failureReason: String?

    public init(
        id: UUID = UUID(),
        configID: UUID,
        configName: String,
        kind: ProtocolKind,
        serverHost: String,
        startedAt: Date,
        endedAt: Date? = nil,
        rxBytes: UInt64 = 0,
        txBytes: UInt64 = 0,
        averageLatencyMillis: Int? = nil,
        failureReason: String? = nil
    ) {
        self.id = id
        self.configID = configID
        self.configName = configName
        self.kind = kind
        self.serverHost = serverHost
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.rxBytes = rxBytes
        self.txBytes = txBytes
        self.averageLatencyMillis = averageLatencyMillis
        self.failureReason = failureReason
    }

    public var duration: TimeInterval { (endedAt ?? Date()).timeIntervalSince(startedAt) }
    public var totalBytes: UInt64 { rxBytes &+ txBytes }
    public var isOpen: Bool { endedAt == nil }
}
