import Foundation

/// How DNS is resolved inside the tunnel.
public enum DNSMode: String, Codable, CaseIterable, Sendable {
    case system = "System"
    case custom = "Custom"
    case doh = "DNS over HTTPS"
    case dot = "DNS over TLS"
}

/// Advanced DNS configuration surfaced under Settings → DNS & Routing and per
/// configuration under the Network tab.
public struct DNSSettings: Codable, Equatable, Sendable {
    public var mode: DNSMode
    /// Plain resolver IPs (for `.system`/`.custom`).
    public var servers: [String]
    /// DoH endpoint template, e.g. `https://cloudflare-dns.com/dns-query`.
    public var dohTemplate: String?
    /// DoT server hostname, e.g. `1dot1dot1dot1.cloudflare-dns.com`.
    public var dotHost: String?
    public var blockMalware: Bool
    public var blockAds: Bool

    public init(
        mode: DNSMode = .doh,
        servers: [String] = ["1.1.1.1", "1.0.0.1"],
        dohTemplate: String? = "https://cloudflare-dns.com/dns-query",
        dotHost: String? = nil,
        blockMalware: Bool = false,
        blockAds: Bool = false
    ) {
        self.mode = mode
        self.servers = servers
        self.dohTemplate = dohTemplate
        self.dotHost = dotHost
        self.blockMalware = blockMalware
        self.blockAds = blockAds
    }

    /// Named resolver presets for the picker.
    public struct Preset: Identifiable, Equatable, Sendable {
        public let name: String
        public let settings: DNSSettings
        public var id: String { name }
    }

    public static let presets: [Preset] = [
        Preset(name: "Cloudflare", settings: DNSSettings(mode: .doh, servers: ["1.1.1.1", "1.0.0.1"], dohTemplate: "https://cloudflare-dns.com/dns-query")),
        Preset(name: "Cloudflare (Malware)", settings: DNSSettings(mode: .doh, servers: ["1.1.1.2", "1.0.0.2"], dohTemplate: "https://security.cloudflare-dns.com/dns-query", blockMalware: true)),
        Preset(name: "Google", settings: DNSSettings(mode: .doh, servers: ["8.8.8.8", "8.8.4.4"], dohTemplate: "https://dns.google/dns-query")),
        Preset(name: "Quad9", settings: DNSSettings(mode: .doh, servers: ["9.9.9.9", "149.112.112.112"], dohTemplate: "https://dns.quad9.net/dns-query", blockMalware: true)),
        Preset(name: "AdGuard", settings: DNSSettings(mode: .doh, servers: ["94.140.14.14", "94.140.15.15"], dohTemplate: "https://dns.adguard-dns.com/dns-query", blockMalware: true, blockAds: true)),
        Preset(name: "System", settings: DNSSettings(mode: .system, servers: [])),
    ]
}
