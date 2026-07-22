import Foundation

/// OpenVPN (TLS · universal). Imported from an `.ovpn` file.
public struct OpenVPNModule: ProtocolModule {
    public init() {}
    public let kind: ProtocolKind = .openvpn

    public var fieldSchema: [FieldSection] {
        [
            SchemaKit.general(name: "OpenVPN US"),
            FieldSection("SERVER", [
                ProtocolField(FieldKey.server, label: "Remote Host", placeholder: "vpn.example.com", level: .required),
                ProtocolField(FieldKey.port, label: "Port", placeholder: "1194", level: .required, input: .number),
                ProtocolField(FieldKey.proto, label: "Protocol", level: .required, input: .select(options: ["udp", "tcp"])),
            ]),
            FieldSection("AUTHENTICATION", [
                ProtocolField(FieldKey.username, label: "Username", level: .optional),
                ProtocolField(FieldKey.password, label: "Password", level: .optional, input: .password),
                ProtocolField(FieldKey.caCertificate, label: "CA Certificate", placeholder: "-----BEGIN CERTIFICATE-----", level: .required, input: .multiline),
            ]),
            FieldSection("TLS", [
                ProtocolField(FieldKey.tlsAuthKey, label: "TLS-Auth Key", placeholder: "ta.key contents", level: .optional, input: .multiline),
                ProtocolField(FieldKey.sni, label: "Verify Server Name (SNI)", placeholder: "vpn.example.com", level: .optional),
                ProtocolField(FieldKey.cipher, label: "Data Cipher", level: .advanced, input: .select(options: ["AES-256-GCM", "AES-128-GCM", "CHACHA20-POLY1305"])),
            ]),
            FieldSection("ADVANCED", [
                ProtocolField(FieldKey.compressionLZO, label: "Compression (LZO)", level: .advanced, input: .toggle(hint: "Legacy — usually off")),
                ProtocolField(FieldKey.mtu, label: "Tunnel MTU", placeholder: "1500", level: .advanced, input: .number),
            ]),
        ]
    }
}
