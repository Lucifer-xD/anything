import Foundation

/// The runtime "core" that actually carries a protocol's traffic inside the
/// Packet Tunnel extension. The UI never sees this — it exists so the tunnel
/// layer can pick the right engine adapter (WireGuardKit, an Xray/sing-box core,
/// an SSH client, etc.) for a given ``ProtocolKind``.
public enum TransportCore: String, Codable, Sendable {
    case wireguard      // WireGuardKit
    case xray           // Xray-core (VLESS/VMess/Trojan/Reality/Shadowsocks/…)
    case singbox        // sing-box (Hysteria2/TUIC and others)
    case ssh            // SSH tunnel (+ SSL/WS/HTTP payload)
    case openvpn        // OpenVPN
    case tls            // stunnel-style TLS wrapper
    case proxy          // plain HTTP/HTTPS/SOCKS proxy via tun2socks
    case dns            // DNS tunnel / SlowDNS
}

/// Every tunnelling protocol Nimbus can model. Each case maps 1:1 to an entry in
/// the protocol picker and owns its own ``ProtocolModule`` (schema, parser,
/// validator, session planner). This is the enum the whole app keys off of.
public enum ProtocolKind: String, Codable, CaseIterable, Identifiable, Sendable {
    // Modern / recommended
    case wireguard
    case reality            // VLESS + Reality (XTLS)
    case hysteria2
    case tuic

    // Xray / V2Ray family
    case vless
    case vmess
    case trojan
    case shadowsocks

    // Classic tunnels
    case ssh
    case openvpn
    case stunnel            // SSL/TLS tunnel

    // Proxies
    case httpProxy
    case httpsProxy
    case socks4
    case socks5

    // Transport-only / niche
    case websocket
    case websocketTLS
    case dnsTunnel          // SlowDNS / DNSTT

    public var id: String { rawValue }

    /// Display metadata (name, abbreviation, tint, tagline, recommendation).
    public var metadata: ProtocolMetadata { ProtocolMetadata.table[self] ?? .fallback(self) }

    /// The runtime core used to carry this protocol.
    public var core: TransportCore {
        switch self {
        case .wireguard: return .wireguard
        case .reality, .vless, .vmess, .trojan, .shadowsocks: return .xray
        case .hysteria2, .tuic: return .singbox
        case .ssh: return .ssh
        case .openvpn: return .openvpn
        case .stunnel, .websocketTLS: return .tls
        case .httpProxy, .httpsProxy, .socks4, .socks5, .websocket: return .proxy
        case .dnsTunnel: return .dns
        }
    }

    /// Whether the protocol natively carries UDP traffic.
    public var supportsUDP: Bool {
        switch self {
        case .wireguard, .hysteria2, .tuic, .reality, .vless, .vmess, .shadowsocks, .socks5:
            return true
        default:
            return false
        }
    }

    /// The dynamic editor schema for this protocol.
    public var fieldSchema: [FieldSection] { ProtocolRegistry.shared.module(for: self).fieldSchema }
}
