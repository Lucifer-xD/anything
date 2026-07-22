import Foundation

/// The time granularity for a usage report.
public enum UsagePeriod: String, CaseIterable, Sendable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"

    var component: Calendar.Component {
        switch self {
        case .daily: return .day
        case .weekly: return .weekOfYear
        case .monthly: return .month
        }
    }
}

/// One bucket of usage (a day / week / month).
public struct UsageBucket: Identifiable, Equatable, Sendable {
    public let periodStart: Date
    public var rxBytes: UInt64
    public var txBytes: UInt64
    public var sessionCount: Int
    public var connectedSeconds: Int
    public var id: Date { periodStart }
    public var totalBytes: UInt64 { rxBytes &+ txBytes }
}

/// Per-protocol or per-server usage slice.
public struct UsageSlice: Identifiable, Equatable, Sendable {
    public let key: String
    public var rxBytes: UInt64
    public var txBytes: UInt64
    public var sessionCount: Int
    public var id: String { key }
    public var totalBytes: UInt64 { rxBytes &+ txBytes }
}

/// Headline totals for the statistics dashboard.
public struct UsageSummary: Equatable, Sendable {
    public var totalRxBytes: UInt64
    public var totalTxBytes: UInt64
    public var sessionCount: Int
    public var totalConnectedSeconds: Int
    public var averageBytesPerSession: UInt64
    public var averageSessionSeconds: Int

    public var totalBytes: UInt64 { totalRxBytes &+ totalTxBytes }

    public static let empty = UsageSummary(totalRxBytes: 0, totalTxBytes: 0, sessionCount: 0, totalConnectedSeconds: 0, averageBytesPerSession: 0, averageSessionSeconds: 0)
}

/// Pure aggregation over session records — no I/O, fully unit-testable. All the
/// statistics screens (daily/weekly/monthly, protocol usage, server usage,
/// averages) are built from these functions.
public enum UsageAggregator {
    public static func summary(_ sessions: [SessionRecord]) -> UsageSummary {
        guard !sessions.isEmpty else { return .empty }
        var rx: UInt64 = 0, tx: UInt64 = 0, seconds = 0
        for session in sessions {
            rx &+= session.rxBytes
            tx &+= session.txBytes
            seconds += Int(session.duration)
        }
        let count = sessions.count
        return UsageSummary(
            totalRxBytes: rx,
            totalTxBytes: tx,
            sessionCount: count,
            totalConnectedSeconds: seconds,
            averageBytesPerSession: UInt64((rx &+ tx) / UInt64(count)),
            averageSessionSeconds: seconds / count
        )
    }

    public static func buckets(_ sessions: [SessionRecord], period: UsagePeriod, calendar: Calendar = .current) -> [UsageBucket] {
        var byStart: [Date: UsageBucket] = [:]
        for session in sessions {
            let start = calendar.dateInterval(of: period.component, for: session.startedAt)?.start
                ?? calendar.startOfDay(for: session.startedAt)
            var bucket = byStart[start] ?? UsageBucket(periodStart: start, rxBytes: 0, txBytes: 0, sessionCount: 0, connectedSeconds: 0)
            bucket.rxBytes &+= session.rxBytes
            bucket.txBytes &+= session.txBytes
            bucket.sessionCount += 1
            bucket.connectedSeconds += Int(session.duration)
            byStart[start] = bucket
        }
        return byStart.values.sorted { $0.periodStart < $1.periodStart }
    }

    public static func byProtocol(_ sessions: [SessionRecord]) -> [UsageSlice] {
        slice(sessions) { $0.kind.metadata.displayName }
    }

    public static func byServer(_ sessions: [SessionRecord]) -> [UsageSlice] {
        slice(sessions) { $0.serverHost }
    }

    private static func slice(_ sessions: [SessionRecord], key: (SessionRecord) -> String) -> [UsageSlice] {
        var byKey: [String: UsageSlice] = [:]
        for session in sessions {
            let k = key(session)
            var slice = byKey[k] ?? UsageSlice(key: k, rxBytes: 0, txBytes: 0, sessionCount: 0)
            slice.rxBytes &+= session.rxBytes
            slice.txBytes &+= session.txBytes
            slice.sessionCount += 1
            byKey[k] = slice
        }
        return byKey.values.sorted { $0.totalBytes > $1.totalBytes }
    }
}
