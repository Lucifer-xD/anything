import Foundation

/// Presentation metadata for a protocol: how it appears in the picker, the
/// library cards and the detail header. Colors are expressed as hex so the core
/// stays UI-framework agnostic; the design system maps them to `Color`.
public struct ProtocolMetadata: Equatable, Sendable {
    public let kind: ProtocolKind
    public let displayName: String
    /// Two-letter badge shown in the square protocol chip (WG, RE, H2, …).
    public let abbreviation: String
    /// Accent hex used for the chip tint (matches the design's palette).
    public let tintHex: String
    /// One-line descriptor under the name in the picker.
    public let tagline: String
    /// Marked "FAST"/recommended in the picker.
    public let isRecommended: Bool

    public static func fallback(_ kind: ProtocolKind) -> ProtocolMetadata {
        ProtocolMetadata(
            kind: kind,
            displayName: kind.rawValue.capitalized,
            abbreviation: String(kind.rawValue.prefix(2)).uppercased(),
            tintHex: "#8E8E93",
            tagline: "Custom tunnel",
            isRecommended: false
        )
    }

    /// The canonical table, ported from the imported design's `PROTO` map and
    /// extended for the additional protocols required by the spec.
    static let table: [ProtocolKind: ProtocolMetadata] = {
        func m(_ k: ProtocolKind, _ name: String, _ abbr: String, _ hex: String, _ tag: String, _ rec: Bool = false) -> (ProtocolKind, ProtocolMetadata) {
            (k, ProtocolMetadata(kind: k, displayName: name, abbreviation: abbr, tintHex: hex, tagline: tag, isRecommended: rec))
        }
        return Dictionary(uniqueKeysWithValues: [
            m(.wireguard,   "WireGuard",       "WG", "#30D158", "Modern · UDP · Fastest", true),
            m(.reality,     "VLESS + Reality", "RE", "#0A84FF", "XTLS · Undetectable", true),
            m(.hysteria2,   "Hysteria2",       "H2", "#BF5AF2", "QUIC · Lossy networks", true),
            m(.tuic,        "TUIC",            "TU", "#30D158", "QUIC · 0-RTT", true),
            m(.vless,       "VLESS",           "VL", "#0A84FF", "V2Ray · WS / gRPC / XTLS"),
            m(.vmess,       "VMess",           "VM", "#FF9F0A", "V2Ray · Encrypted"),
            m(.trojan,      "Trojan",          "TR", "#FF453A", "TLS · Looks like HTTPS"),
            m(.shadowsocks, "Shadowsocks",     "SS", "#64D2FF", "SOCKS5 · AEAD"),
            m(.ssh,         "SSH",             "SH", "#FF9F0A", "SSH · SSL / WS / HTTP payload"),
            m(.openvpn,     "OpenVPN",         "OV", "#FFD60A", "TLS · Universal"),
            m(.stunnel,     "SSL/TLS Tunnel",  "ST", "#64D2FF", "TLS wrapper · SNI"),
            m(.httpProxy,   "HTTP Proxy",      "HT", "#8E8E93", "Plain HTTP CONNECT"),
            m(.httpsProxy,  "HTTPS Proxy",     "HS", "#64D2FF", "TLS HTTP CONNECT"),
            m(.socks4,      "SOCKS4",          "S4", "#8E8E93", "Legacy SOCKS"),
            m(.socks5,      "SOCKS5",          "S5", "#5E5CE6", "SOCKS5 · UDP"),
            m(.websocket,   "WebSocket",       "WS", "#8E8E93", "Raw WebSocket transport"),
            m(.websocketTLS,"WebSocket · TLS", "WT", "#64D2FF", "WebSocket over TLS"),
            m(.dnsTunnel,   "DNS Tunnel",      "DN", "#FF9F0A", "SlowDNS · DNSTT"),
        ])
    }()
}
