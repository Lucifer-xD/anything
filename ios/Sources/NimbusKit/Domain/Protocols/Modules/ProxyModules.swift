import Foundation

/// SOCKS4 / SOCKS5 proxy. SOCKS5 additionally offers username/password auth and
/// UDP relay. One module type serves both, parameterized by kind.
public struct SOCKSModule: ProtocolModule {
    public let kind: ProtocolKind
    public init(kind: ProtocolKind) { self.kind = kind }

    public var uriSchemes: [String] { kind == .socks5 ? ["socks5", "socks"] : ["socks4"] }

    public var fieldSchema: [FieldSection] {
        var auth: [ProtocolField] = []
        if kind == .socks5 {
            auth = [
                ProtocolField(FieldKey.username, label: "Username", level: .optional),
                ProtocolField(FieldKey.password, label: "Password", level: .optional, input: .password),
            ]
        }
        return [
            SchemaKit.general(name: kind.metadata.displayName),
            FieldSection("SERVER", [
                ProtocolField(FieldKey.server, label: "Host", placeholder: "proxy.example.com", level: .required),
                ProtocolField(FieldKey.port, label: "Port", placeholder: "1080", level: .required, input: .number),
            ]),
            FieldSection("AUTHENTICATION", auth.isEmpty ? [ProtocolField(FieldKey.username, label: "Username", level: .optional)] : auth),
            FieldSection("ADVANCED", [
                ProtocolField(FieldKey.udpRelayMode, label: "UDP Relay", level: .advanced, input: .toggle(hint: kind == .socks5 ? "SOCKS5 UDP associate" : "Not supported on SOCKS4")),
            ]),
        ]
    }

    public func parse(_ uri: ConfigURI) throws -> TunnelConfiguration? {
        guard uriSchemes.contains(uri.scheme), let host = uri.host else { return nil }
        var fields = ConfigFields()
        fields.set(FieldKey.name, uri.fragment ?? host)
        fields.set(FieldKey.server, host)
        fields.set(FieldKey.port, uri.port ?? 1080)
        if let user = uri.user {
            // May be base64(user:pass) or user:pass.
            let decoded = user.base64DecodedString() ?? user
            let parts = decoded.split(separator: ":", maxSplits: 1).map(String.init)
            if let u = parts.first { fields.set(FieldKey.username, u) }
            if parts.count == 2 { fields.set(FieldKey.password, parts[1]) }
        }
        return TunnelConfiguration(kind: kind, fields: fields, metadata: ConfigMetadata(source: .clipboard))
    }
}

/// Plain HTTP / HTTPS proxy (CONNECT). HTTPS adds a TLS/SNI section.
public struct HTTPProxyModule: ProtocolModule {
    public let kind: ProtocolKind
    public init(kind: ProtocolKind) { self.kind = kind }

    public var uriSchemes: [String] { kind == .httpsProxy ? ["https"] : ["http"] }

    public var fieldSchema: [FieldSection] {
        var sections: [FieldSection] = [
            SchemaKit.general(name: kind.metadata.displayName),
            FieldSection("SERVER", [
                ProtocolField(FieldKey.server, label: "Host", placeholder: "proxy.example.com", level: .required),
                ProtocolField(FieldKey.port, label: "Port", placeholder: "8080", level: .required, input: .number),
            ]),
            FieldSection("AUTHENTICATION", [
                ProtocolField(FieldKey.username, label: "Username", level: .optional),
                ProtocolField(FieldKey.password, label: "Password", level: .optional, input: .password),
            ]),
        ]
        if kind == .httpsProxy {
            sections.append(FieldSection("TLS", [
                ProtocolField(FieldKey.sni, label: "SNI", placeholder: "proxy.example.com", level: .optional),
                ProtocolField(FieldKey.allowInsecure, label: "Allow Insecure", level: .advanced, input: .toggle(hint: "Skip cert verification")),
            ]))
        }
        return sections
    }
}

/// WebSocket / WebSocket-over-TLS transport, usable standalone as a relay hop or
/// as a building block for payload tunnels.
public struct WebSocketModule: ProtocolModule {
    public let kind: ProtocolKind
    public init(kind: ProtocolKind) { self.kind = kind }

    public var fieldSchema: [FieldSection] {
        var sections: [FieldSection] = [
            SchemaKit.general(name: kind.metadata.displayName),
            FieldSection("SERVER", [
                ProtocolField(FieldKey.server, label: "Host", placeholder: "cdn.example.com", level: .required),
                ProtocolField(FieldKey.port, label: "Port", placeholder: kind == .websocketTLS ? "443" : "80", level: .required, input: .number),
            ]),
            FieldSection("WEBSOCKET", [
                ProtocolField(FieldKey.path, label: "Path", placeholder: "/ws", level: .required),
                ProtocolField(FieldKey.hostHeader, label: "Host Header", placeholder: "cdn.example.com", level: .optional),
            ]),
        ]
        if kind == .websocketTLS {
            sections.append(FieldSection("TLS", [
                ProtocolField(FieldKey.sni, label: "SNI", level: .optional),
                ProtocolField(FieldKey.alpn, label: "ALPN", level: .optional, input: .select(options: ["http/1.1", "h2"])),
                ProtocolField(FieldKey.allowInsecure, label: "Allow Insecure", level: .advanced, input: .toggle(hint: "Skip cert verification")),
            ]))
        }
        return sections
    }
}

/// DNS Tunnel / SlowDNS (DNSTT). Encapsulates traffic in DNS queries — slow but
/// often works where everything else is blocked.
public struct DNSTunnelModule: ProtocolModule {
    public init() {}
    public let kind: ProtocolKind = .dnsTunnel

    public var fieldSchema: [FieldSection] {
        [
            SchemaKit.general(name: "SlowDNS"),
            FieldSection("SERVER", [
                ProtocolField(FieldKey.server, label: "Name Server (NS)", placeholder: "ns.example.com", level: .required),
                ProtocolField(FieldKey.port, label: "Resolver Port", placeholder: "53", level: .optional, input: .number),
            ]),
            FieldSection("KEYS", [
                ProtocolField(FieldKey.realityPublicKey, label: "Server Public Key", placeholder: "dnstt public key", level: .required, input: .multiline),
            ]),
            FieldSection("UPSTREAM", [
                ProtocolField(FieldKey.dns, label: "DoH / UDP Resolver", placeholder: "https://1.1.1.1/dns-query", level: .optional),
                ProtocolField(FieldKey.mtu, label: "MTU", placeholder: "1232", level: .advanced, input: .number),
            ]),
        ]
    }
}
