import Foundation

/// A bounded, observable log buffer powering the Live Log screen: append,
/// filter, live streaming (auto-scroll), export, share, clear.
public actor LogStore {
    private var buffer: [LogEntry]
    private let capacity: Int
    private let broadcaster = AsyncBroadcaster<LogEntry>()

    public init(capacity: Int = 2000, seed: [LogEntry] = []) {
        self.capacity = capacity
        self.buffer = Array(seed.suffix(capacity))
    }

    public func append(_ entry: LogEntry) async {
        buffer.append(entry)
        if buffer.count > capacity { buffer.removeFirst(buffer.count - capacity) }
        await broadcaster.emit(entry)
    }

    public func log(_ level: LogLevel, _ message: String, category: String = "tunnel", at date: Date = Date()) async {
        await append(LogEntry(timestamp: date, level: level, category: category, message: message))
    }

    public func all() -> [LogEntry] { buffer }

    public func filtered(_ filter: LogFilter, search: String = "") -> [LogEntry] {
        let needle = search.trimmingCharacters(in: .whitespaces).lowercased()
        return buffer.filter { entry in
            guard filter.matches(entry.level) else { return false }
            guard !needle.isEmpty else { return true }
            return entry.message.lowercased().contains(needle) || entry.category.lowercased().contains(needle)
        }
    }

    /// A live stream of new entries (for auto-scroll consoles).
    public func stream() async -> AsyncStream<LogEntry> {
        await broadcaster.stream()
    }

    public func clear() {
        buffer.removeAll()
    }

    /// The whole buffer rendered as copyable / exportable plain text.
    public func exportText(_ filter: LogFilter = .all) -> String {
        filtered(filter).map(\.plainText).joined(separator: "\n")
    }
}
