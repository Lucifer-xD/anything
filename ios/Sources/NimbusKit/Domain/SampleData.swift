import Foundation

/// Deterministic sample content mirroring the imported design's mock library.
/// Used to seed a fresh install for first-run delight, to drive SwiftUI previews,
/// and as fixtures in tests. All ids and dates are fixed for stability.
public enum SampleData {
    private static func date(_ offsetDays: Double) -> Date {
        Date(timeIntervalSince1970: 1_752_000_000).addingTimeInterval(offsetDays * 86_400)
    }
    private static func id(_ hex: String) -> UUID { UUID(uuidString: hex)! }

    // Folder ids from ConfigFolder.defaults
    private static let personal = ConfigFolder.defaults[0].id
    private static let work = ConfigFolder.defaults[1].id
    private static let gaming = ConfigFolder.defaults[2].id
    private static let subs = ConfigFolder.defaults[3].id

    private static func config(
        _ hex: String, name: String, kind: ProtocolKind, fields: [String: ConfigValue],
        group: String, folder: UUID, tags: [String], latency: Int, trafficGB: Double,
        favorite: Bool = false, pinned: Bool = false, lastDays: Double
    ) -> TunnelConfiguration {
        var f = ConfigFields(fields)
        f.set(FieldKey.name, name)
        let meta = ConfigMetadata(
            folderID: folder, group: group, tags: tags,
            isFavorite: favorite, isPinned: pinned,
            source: .manual,
            createdAt: date(-30), updatedAt: date(-lastDays),
            lastConnectedAt: date(-lastDays),
            latencyMillis: latency,
            trafficBytes: UInt64(trafficGB * 1_073_741_824),
            sessionCount: Int(trafficGB * 12)
        )
        return TunnelConfiguration(id: id(hex), kind: kind, fields: f, metadata: meta)
    }

    public static let configurations: [TunnelConfiguration] = [
        config("11111111-0000-0000-0000-0000000000A1", name: "Reality — Frankfurt", kind: .reality,
               fields: [
                FieldKey.server: "de1.nimbus.net", FieldKey.port: 443,
                FieldKey.uuid: "d3adb33f-1234-5678-9abc-def012345678",
                FieldKey.flow: "xtls-rprx-vision", FieldKey.security: "reality",
                FieldKey.sni: "www.apple.com", FieldKey.fingerprint: "chrome",
                FieldKey.realityPublicKey: "l8y2R7dQv0nF3kP9wXhQ2mB5cJ1tZ4sU6aH8eD0gK",
                FieldKey.shortID: "0123abcd", FieldKey.network: "tcp",
               ],
               group: "Personal", folder: personal, tags: ["Streaming"],
               latency: 27, trafficGB: 12.4, favorite: true, pinned: true, lastDays: 0.001),
        config("22222222-0000-0000-0000-0000000000A2", name: "WireGuard NL", kind: .wireguard,
               fields: [
                FieldKey.interfacePrivateKey: "aF3k...=", FieldKey.address: "10.66.0.2/32, fd00::2/128",
                FieldKey.dns: "1.1.1.1, 2606:4700::1111", FieldKey.mtu: 1420,
                FieldKey.peerPublicKey: "bG4l...=", FieldKey.endpoint: "nl.wg.example.io:51820",
                FieldKey.allowedIPs: "0.0.0.0/0, ::/0", FieldKey.keepAlive: 25,
                FieldKey.server: "nl.wg.example.io", FieldKey.port: 51820,
               ],
               group: "Personal", folder: personal, tags: ["Torrent"],
               latency: 29, trafficGB: 4.2, favorite: true, lastDays: 0.5),
        config("33333333-0000-0000-0000-0000000000A3", name: "Tokyo Gaming", kind: .hysteria2,
               fields: [
                FieldKey.server: "jp.hy2.gg", FieldKey.port: 8443,
                FieldKey.auth: "s3cr3t-token", FieldKey.sni: "example.com",
                FieldKey.up: 50, FieldKey.down: 200, FieldKey.obfs: "salamander",
               ],
               group: "Gaming", folder: gaming, tags: ["Gaming"],
               latency: 96, trafficGB: 0.8, lastDays: 1),
        config("44444444-0000-0000-0000-0000000000A4", name: "Work — Trojan", kind: .trojan,
               fields: [
                FieldKey.server: "edge.corp.dev", FieldKey.port: 443,
                FieldKey.password: "corp-trojan-pw", FieldKey.sni: "corp.dev",
                FieldKey.network: "ws", FieldKey.path: "/tunnel",
               ],
               group: "Work", folder: work, tags: ["Work"],
               latency: 31, trafficGB: 2.1, lastDays: 3),
        config("55555555-0000-0000-0000-0000000000A5", name: "SG Shadowsocks", kind: .shadowsocks,
               fields: [
                FieldKey.server: "sg.ss.stream", FieldKey.port: 8388,
                FieldKey.password: "ss-password", FieldKey.cipher: "aes-256-gcm",
               ],
               group: "Subscriptions", folder: subs, tags: ["Streaming"],
               latency: 88, trafficGB: 6.7, lastDays: 7),
        config("66666666-0000-0000-0000-0000000000A6", name: "US VMess WS", kind: .vmess,
               fields: [
                FieldKey.server: "us.v2.cloud", FieldKey.port: 443,
                FieldKey.uuid: "abcd1234-5678-90ab-cdef-1234567890ab",
                FieldKey.network: "ws", FieldKey.path: "/ray",
                FieldKey.security: "tls", FieldKey.sni: "cdn.example.com",
               ],
               group: "Subscriptions", folder: subs, tags: [],
               latency: 22, trafficGB: 9.3, lastDays: 7),
    ]

    public static let subscriptions: [Subscription] = [
        Subscription(id: id("77777777-0000-0000-0000-0000000000B1"), name: "Nimbus Premium",
                     url: URL(string: "https://sub.nimbus.net/u/8f2a")!, folderID: subs,
                     lastUpdated: date(-0.008), nodeCount: 42, expiresAt: date(46),
                     usedBytes: 82 * 1_073_741_824, totalBytes: 500 * 1_073_741_824, tintHex: "#0A84FF"),
        Subscription(id: id("77777777-0000-0000-0000-0000000000B2"), name: "StreamNodes",
                     url: URL(string: "https://streamnodes.io/api/v1/sub")!, folderID: subs,
                     lastUpdated: date(-0.08), nodeCount: 18, expiresAt: date(6),
                     usedBytes: 12 * 1_073_741_824, totalBytes: 100 * 1_073_741_824, tintHex: "#30D158"),
        Subscription(id: id("77777777-0000-0000-0000-0000000000B3"), name: "Community Free",
                     url: URL(string: "https://raw.githubusercontent.com/free/sub.txt")!, folderID: subs,
                     lastUpdated: date(-1), nodeCount: 120, tintHex: "#BF5AF2"),
    ]

    public static let servers: [Server] = [
        Server(name: "Frankfurt 1", host: "de1.nimbus.net", port: 443, countryCode: "DE", city: "Frankfurt", category: "Streaming", tags: ["Reality"], isFavorite: true, latencyMillis: 27, health: .healthy),
        Server(name: "Amsterdam", host: "nl.wg.example.io", port: 51820, countryCode: "NL", city: "Amsterdam", category: "P2P", tags: ["WireGuard"], isFavorite: true, latencyMillis: 29, health: .healthy),
        Server(name: "Tokyo", host: "jp.hy2.gg", port: 8443, countryCode: "JP", city: "Tokyo", category: "Gaming", tags: ["QUIC"], latencyMillis: 96, health: .degraded),
        Server(name: "London Edge", host: "edge.corp.dev", port: 443, countryCode: "GB", city: "London", category: "Work", latencyMillis: 31, health: .healthy),
        Server(name: "Singapore", host: "sg.ss.stream", port: 8388, countryCode: "SG", city: "Singapore", category: "Streaming", latencyMillis: 88, health: .degraded),
        Server(name: "New York", host: "us.v2.cloud", port: 443, countryCode: "US", city: "New York", category: "General", latencyMillis: 22, health: .healthy),
    ]

    public static let logs: [LogEntry] = {
        let base = Date(timeIntervalSince1970: 1_752_000_000)
        func e(_ secs: Double, _ level: LogLevel, _ message: String) -> LogEntry {
            LogEntry(timestamp: base.addingTimeInterval(secs), level: level, message: message)
        }
        return [
            e(0.114, .info, "Parsing config \"Reality — Frankfurt\""),
            e(0.121, .info, "Selected protocol VLESS + Reality"),
            e(0.298, .info, "Resolving de1.nimbus.net:443"),
            e(0.451, .ok,   "TLS handshake — SNI www.apple.com"),
            e(0.702, .ok,   "Reality authenticated — vision flow"),
            e(0.710, .info, "DNS set to 10.66.0.1 (DoH)"),
            e(0.988, .warning, "MTU 1420 below path MTU — clamping"),
            e(1.004, .ok,   "Kill switch armed"),
            e(1.220, .info, "Route 0.0.0.0/0 via tunnel"),
            e(9.517, .info, "rx 2.4 MB · tx 812 KB"),
            e(29.882, .error, "Probe timeout — retry (1/3)"),
            e(30.140, .ok,  "Link restored — 27 ms"),
        ]
    }()

    /// A ready-to-use store snapshot for seeding a fresh install / previews.
    public static var snapshot: StoreSnapshot {
        StoreSnapshot(configs: configurations, folders: ConfigFolder.defaults, subscriptions: subscriptions)
    }
}
