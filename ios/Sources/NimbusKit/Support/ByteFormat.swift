import Foundation

/// Human formatting for bytes, rates and durations — shared by the dashboard,
/// statistics and logs so units read consistently everywhere.
public enum ByteFormat {
    private static let units = ["B", "KB", "MB", "GB", "TB", "PB"]

    /// `12.4 GB`, `820 MB`, `1.0 KB`.
    public static func short(_ bytes: UInt64) -> String {
        var value = Double(bytes)
        var index = 0
        while value >= 1024, index < units.count - 1 {
            value /= 1024
            index += 1
        }
        let precision = (index == 0 || value >= 100) ? 0 : 1
        return String(format: "%.\(precision)f %@", value, units[index])
    }

    /// `187.4 Mbps` from bits/second.
    public static func rate(bitsPerSecond: Double) -> String {
        let mbps = bitsPerSecond / 1_000_000
        if mbps >= 1000 { return String(format: "%.2f Gbps", mbps / 1000) }
        return String(format: "%.1f Mbps", mbps)
    }

    /// `1:04:22` or `04:22` session-timer style.
    public static func duration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        func pad(_ n: Int) -> String { String(format: "%02d", n) }
        return h > 0 ? "\(h):\(pad(m)):\(pad(s))" : "\(pad(m)):\(pad(s))"
    }
}
