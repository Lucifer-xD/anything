import Foundation

/// A `host:port` pair with IPv6-bracket awareness. Used when a protocol stores
/// its endpoint as a single string (WireGuard `Endpoint`, stunnel `connect`).
public struct Endpoint: Equatable, Sendable {
    public var host: String
    public var port: Int

    public init(host: String, port: Int) {
        self.host = host
        self.port = port
    }

    /// Parses `host:port`, `[v6]:port`, or a bare host (port becomes 0).
    public init?(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // [2001:db8::1]:51820
        if trimmed.hasPrefix("[") {
            guard let close = trimmed.firstIndex(of: "]") else { return nil }
            host = String(trimmed[trimmed.index(after: trimmed.startIndex)..<close])
            let rest = trimmed[trimmed.index(after: close)...]
            if rest.hasPrefix(":"), let port = Int(rest.dropFirst()) {
                self.port = port
            } else {
                self.port = 0
            }
            return
        }

        // Ambiguous colon: bare IPv6 without brackets (more than one colon) -> no port.
        let colons = trimmed.filter { $0 == ":" }.count
        if colons > 1 {
            host = trimmed
            port = 0
            return
        }

        if let colon = trimmed.lastIndex(of: ":"), let port = Int(trimmed[trimmed.index(after: colon)...]) {
            host = String(trimmed[..<colon])
            self.port = port
        } else {
            host = trimmed
            port = 0
        }
    }

    public var description: String {
        host.contains(":") ? "[\(host)]:\(port)" : "\(host):\(port)"
    }
}
