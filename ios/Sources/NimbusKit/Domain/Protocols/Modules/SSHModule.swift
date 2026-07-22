import Foundation

/// SSH tunnel with the "payload" modes that define HTTP-Injector-class apps:
/// Direct, SSL/TLS, WebSocket, and raw HTTP payload (with `[crlf]`, `[host]`,
/// `[split]` tokens). Imported from `.ehi`/`.hc`-style bundles, not a URI.
public struct SSHModule: ProtocolModule {
    public init() {}
    public let kind: ProtocolKind = .ssh

    public var fieldSchema: [FieldSection] {
        [
            SchemaKit.general(name: "SSH Tunnel"),
            FieldSection("SERVER", [
                ProtocolField(FieldKey.server, label: "Host", placeholder: "ssh.example.com", level: .required),
                ProtocolField(FieldKey.port, label: "Port", placeholder: "22", level: .required, input: .number),
            ]),
            FieldSection("AUTHENTICATION", [
                ProtocolField(FieldKey.username, label: "Username", placeholder: "root", level: .required),
                ProtocolField(FieldKey.password, label: "Password", level: .optional, input: .password),
                ProtocolField(FieldKey.privateKey, label: "Private Key", placeholder: "-----BEGIN OPENSSH PRIVATE KEY-----", level: .optional, input: .multiline),
            ]),
            FieldSection("PAYLOAD MODE", [
                ProtocolField(FieldKey.tunnelMode, label: "Tunnel Mode", level: .required, input: .select(options: ["Direct", "SSL/TLS", "WebSocket", "HTTP"])),
                ProtocolField(FieldKey.sni, label: "SNI / SSL Host", placeholder: "bug.example.com", level: .optional),
                ProtocolField(FieldKey.httpPayload, label: "Custom HTTP Payload", placeholder: "GET / HTTP/1.1[crlf]Host: [host][crlf][crlf]", level: .advanced, input: .multiline),
                ProtocolField(FieldKey.webSocketHost, label: "WebSocket Host", placeholder: "cdn.example.com", level: .optional),
            ]),
            FieldSection("ADVANCED", [
                ProtocolField(FieldKey.compression, label: "Compression", level: .advanced, input: .toggle(hint: "zlib@openssh")),
                ProtocolField(FieldKey.keepAlive, label: "Keepalive (s)", placeholder: "30", level: .advanced, input: .number),
            ]),
        ]
    }

    public func validate(_ config: TunnelConfiguration) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        for field in fieldSchema.allFields where field.level == .required {
            if config.fields[field.key]?.isEmpty != false { issues.append(.required(field.key, field.label)) }
        }
        // Need either a password or a private key.
        let hasPassword = config.fields[FieldKey.password]?.isEmpty == false
        let hasKey = config.fields[FieldKey.privateKey]?.isEmpty == false
        if !hasPassword && !hasKey {
            issues.append(ValidationIssue(fieldKey: FieldKey.password, severity: .error, message: "Provide a password or a private key."))
        }
        return issues
    }
}
