import Foundation

/// SSL/TLS tunnel (stunnel-style wrapper with SNI). Wraps an upstream endpoint
/// in TLS and exposes it on a local accept address.
public struct StunnelModule: ProtocolModule {
    public init() {}
    public let kind: ProtocolKind = .stunnel

    public var fieldSchema: [FieldSection] {
        [
            SchemaKit.general(name: "Stunnel Wrap"),
            FieldSection("ENDPOINT", [
                ProtocolField(FieldKey.accept, label: "Accept (local)", placeholder: "127.0.0.1:1080", level: .required),
                ProtocolField(FieldKey.server, label: "Connect Host", placeholder: "tls.example.com", level: .required),
                ProtocolField(FieldKey.port, label: "Connect Port", placeholder: "443", level: .required, input: .number),
            ]),
            FieldSection("TLS", [
                ProtocolField(FieldKey.sni, label: "SNI (Server Name)", placeholder: "tls.example.com", level: .required),
                ProtocolField(FieldKey.verifyChain, label: "Verify Certificate Chain", level: .advanced, input: .toggle(hint: "verifyChain = yes")),
                ProtocolField(FieldKey.caCertificate, label: "CA Certificate", placeholder: "-----BEGIN CERTIFICATE-----", level: .optional, input: .multiline),
            ]),
            FieldSection("ADVANCED", [
                ProtocolField(FieldKey.cipher, label: "Cipher Suite", level: .advanced, input: .select(options: ["TLS1.3", "TLS1.2", "auto"])),
                ProtocolField(FieldKey.timeout, label: "TIMEOUTclose (s)", placeholder: "0", level: .experimental, input: .number),
            ]),
        ]
    }
}
