import Foundation

/// Severity of a log line. Ordered so filters can show "this level and above".
public enum LogLevel: Int, Codable, CaseIterable, Comparable, Sendable {
    case debug = 0
    case info = 1
    case ok = 2
    case warning = 3
    case error = 4

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Short tag rendered in the console gutter (matches the design).
    public var tag: String {
        switch self {
        case .debug: return "DBG"
        case .info: return "INFO"
        case .ok: return "OK"
        case .warning: return "WARN"
        case .error: return "ERR"
        }
    }

    /// Console tint hex (matches the design's log colors).
    public var tintHex: String {
        switch self {
        case .debug: return "#8E8E93"
        case .info: return "#0A84FF"
        case .ok: return "#30D158"
        case .warning: return "#FF9F0A"
        case .error: return "#FF453A"
        }
    }
}

/// The filter buckets shown as chips above the console.
public enum LogFilter: String, CaseIterable, Sendable {
    case all = "All"
    case info = "Info"
    case warnings = "Warnings"
    case errors = "Errors"

    public func matches(_ level: LogLevel) -> Bool {
        switch self {
        case .all: return true
        case .info: return level == .info || level == .ok || level == .debug
        case .warnings: return level == .warning
        case .errors: return level == .error
        }
    }
}

/// One structured log line. `category` groups related events (tunnel, dns,
/// parser, sync, …) so logs can be filtered by subsystem too.
public struct LogEntry: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var timestamp: Date
    public var level: LogLevel
    public var category: String
    public var message: String

    public init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        level: LogLevel,
        category: String = "tunnel",
        message: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// `21:04:02.114` timestamp string used by the console.
    public var timeString: String { Self.formatter.string(from: timestamp) }

    /// A single-line, copy/export-friendly rendering.
    public var plainText: String { "\(timeString) \(level.tag.padding(toLength: 4, withPad: " ", startingAt: 0)) [\(category)] \(message)" }
}
