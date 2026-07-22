import Foundation

/// WireGuard. Imported from a `.conf` file (see ``WireGuardConfParser``) rather
/// than a URI. Runs on WireGuardKit inside the Packet Tunnel extension.
public struct WireGuardModule: ProtocolModule {
    public init() {}
    public let kind: ProtocolKind = .wireguard

    public var fieldSchema: [FieldSection] {
        [
            SchemaKit.general(name: "WireGuard NL"),
            FieldSection("INTERFACE", [
                ProtocolField(FieldKey.interfacePrivateKey, label: "Private Key", placeholder: "base64 private key", level: .required, input: .password),
                ProtocolField(FieldKey.address, label: "Address", placeholder: "10.66.0.2/32, fd00::2/128", level: .required),
                ProtocolField(FieldKey.dns, label: "DNS", placeholder: "1.1.1.1, 2606:4700::1111", level: .optional),
                ProtocolField(FieldKey.mtu, label: "MTU", placeholder: "1420", level: .advanced, input: .number),
            ]),
            FieldSection("PEER", [
                ProtocolField(FieldKey.peerPublicKey, label: "Public Key", placeholder: "peer public key", level: .required, input: .password),
                ProtocolField(FieldKey.presharedKey, label: "Preshared Key", placeholder: "optional", level: .optional, input: .password),
                ProtocolField(FieldKey.endpoint, label: "Endpoint", placeholder: "nl.wg.example.io:51820", level: .required),
                ProtocolField(FieldKey.allowedIPs, label: "Allowed IPs", placeholder: "0.0.0.0/0, ::/0", level: .advanced),
                ProtocolField(FieldKey.keepAlive, label: "Persistent Keepalive", placeholder: "25", level: .advanced, input: .number),
            ]),
        ]
    }

    public func validate(_ config: TunnelConfiguration) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        for field in fieldSchema.allFields where field.level == .required {
            if config.fields[field.key]?.isEmpty != false { issues.append(.required(field.key, field.label)) }
        }
        if let endpoint = config.fields.string(FieldKey.endpoint), Endpoint(endpoint)?.port == nil {
            issues.append(ValidationIssue(fieldKey: FieldKey.endpoint, severity: .warning, message: "Endpoint should be host:port."))
        }
        return issues
    }

    public func makeSessionPlan(_ config: TunnelConfiguration) throws -> SessionPlan {
        let endpoint = Endpoint(config.fields.string(FieldKey.endpoint) ?? "") ?? Endpoint(host: config.host, port: config.port)
        let dns = (config.fields.string(FieldKey.dns) ?? "")
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let allowed = (config.fields.string(FieldKey.allowedIPs) ?? "0.0.0.0/0, ::/0")
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return SessionPlan(
            configID: config.id,
            displayName: config.name,
            kind: kind,
            core: .wireguard,
            host: endpoint.host,
            port: endpoint.port,
            dnsServers: dns.isEmpty ? ["1.1.1.1"] : dns,
            mtu: config.fields.int(FieldKey.mtu) ?? 1420,
            includedRoutes: allowed,
            parameters: [
                "private_key": config.fields.string(FieldKey.interfacePrivateKey) ?? "",
                "public_key": config.fields.string(FieldKey.peerPublicKey) ?? "",
                "preshared_key": config.fields.string(FieldKey.presharedKey) ?? "",
                "address": config.fields.string(FieldKey.address) ?? "",
                "keepalive": String(config.fields.int(FieldKey.keepAlive) ?? 0),
            ]
        )
    }
}
