import Foundation

/// VLESS + Reality (XTLS). A distinct editor experience from plain VLESS — it
/// surfaces the Reality-specific fields (public key, short id, spiderX) as
/// first-class. Import is handled by ``VLESSModule`` (which tags reality links as
/// this kind), so this module claims no scheme of its own.
public struct RealityModule: ProtocolModule {
    public init() {}
    public let kind: ProtocolKind = .reality

    public var fieldSchema: [FieldSection] {
        [
            SchemaKit.general(name: "Reality — Frankfurt"),
            SchemaKit.server(host: "de1.nimbus.net"),
            FieldSection("AUTHENTICATION", [
                ProtocolField(FieldKey.uuid, label: "UUID", placeholder: "xxxxxxxx-xxxx-…", level: .required),
                ProtocolField(FieldKey.flow, label: "Flow", level: .optional, input: .select(options: ["none", "xtls-rprx-vision"])),
            ]),
            FieldSection("REALITY / TLS", [
                ProtocolField(FieldKey.security, label: "Security", level: .required, input: .select(options: ["reality", "tls", "none"])),
                ProtocolField(FieldKey.sni, label: "SNI (Server Name)", placeholder: "www.apple.com", level: .required),
                ProtocolField(FieldKey.fingerprint, label: "Fingerprint", level: .optional, input: .select(options: ["chrome", "firefox", "safari", "random"])),
                ProtocolField(FieldKey.realityPublicKey, label: "Public Key", placeholder: "reality public key", level: .required, input: .password),
                ProtocolField(FieldKey.shortID, label: "Short ID", placeholder: "0123abcd", level: .optional),
                ProtocolField(FieldKey.spiderX, label: "SpiderX", placeholder: "/", level: .experimental),
            ]),
            FieldSection("TRANSPORT", [
                ProtocolField(FieldKey.network, label: "Network", level: .required, input: .select(options: ["tcp", "ws", "grpc", "xhttp"])),
                ProtocolField(FieldKey.path, label: "Path", placeholder: "/", level: .optional),
                ProtocolField(FieldKey.hostHeader, label: "Host Header", level: .optional),
            ]),
            FieldSection("ADVANCED", [
                ProtocolField(FieldKey.multiplex, label: "Multiplexing", level: .advanced, input: .toggle(hint: "Reuse a single connection")),
                ProtocolField(FieldKey.sniffing, label: "Traffic Sniffing", level: .advanced, input: .toggle(hint: "Route by detected domain")),
            ]),
        ]
    }

    public func exportURI(_ config: TunnelConfiguration) -> String? {
        // Reality links share the vless:// wire format.
        VLESSModule().exportURI(config)
    }
}
