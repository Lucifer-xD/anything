import Foundation

/// TUIC v5 (QUIC · 0-RTT). Owns `tuic://`.
///
/// Grammar: `tuic://<uuid>:<password>@<host>:<port>?<params>#<name>`
/// Params: `sni` `alpn` `congestion_control` `udp_relay_mode` `allow_insecure`.
public struct TUICModule: ProtocolModule {
    public init() {}
    public let kind: ProtocolKind = .tuic
    public let uriSchemes = ["tuic"]

    public var fieldSchema: [FieldSection] {
        [
            SchemaKit.general(name: "TUIC Node"),
            SchemaKit.server(host: "tuic.example.net"),
            FieldSection("AUTHENTICATION", [
                ProtocolField(FieldKey.uuid, label: "UUID", placeholder: "xxxxxxxx-xxxx-…", level: .required),
                ProtocolField(FieldKey.password, label: "Password", placeholder: "token", level: .required, input: .password),
            ]),
            FieldSection("TLS", [
                ProtocolField(FieldKey.sni, label: "SNI", placeholder: "example.net", level: .required),
                ProtocolField(FieldKey.alpn, label: "ALPN", level: .optional, input: .select(options: ["h3", "h2"])),
                ProtocolField(FieldKey.allowInsecure, label: "Allow Insecure", level: .advanced, input: .toggle(hint: "Skip cert verification")),
            ]),
            FieldSection("ADVANCED", [
                ProtocolField(FieldKey.congestionControl, label: "Congestion Control", level: .advanced, input: .select(options: ["bbr", "cubic", "new_reno"])),
                ProtocolField(FieldKey.udpRelayMode, label: "UDP Relay Mode", level: .advanced, input: .select(options: ["native", "quic"])),
                ProtocolField(FieldKey.zeroRTT, label: "Zero-RTT Handshake", level: .experimental, input: .toggle(hint: "Faster, slightly less secure")),
            ]),
        ]
    }

    public func parse(_ uri: ConfigURI) throws -> TunnelConfiguration? {
        guard uri.scheme == "tuic" else { return nil }
        guard let host = uri.host else {
            throw NimbusError.parseFailure(scheme: "tuic", reason: "missing host")
        }
        var uuid: String?
        var password: String?
        if let user = uri.user {
            let parts = user.split(separator: ":", maxSplits: 1).map(String.init)
            uuid = parts.first
            if parts.count == 2 { password = parts[1] }
        }
        guard let uuid else {
            throw NimbusError.parseFailure(scheme: "tuic", reason: "missing uuid")
        }
        var fields = ConfigFields()
        fields.set(FieldKey.name, uri.fragment ?? host)
        fields.set(FieldKey.server, host)
        fields.set(FieldKey.port, uri.port ?? 443)
        fields.set(FieldKey.uuid, uuid)
        fields.setIfPresent(FieldKey.password, password)
        fields.setIfPresent(FieldKey.sni, uri.query("sni"))
        fields.setIfPresent(FieldKey.alpn, uri.query("alpn"))
        fields.setIfPresent(FieldKey.congestionControl, uri.query("congestion_control"))
        fields.setIfPresent(FieldKey.udpRelayMode, uri.query("udp_relay_mode"))
        if uri.query("allow_insecure") == "1" { fields.set(FieldKey.allowInsecure, true) }
        return TunnelConfiguration(kind: .tuic, fields: fields, metadata: ConfigMetadata(source: .clipboard))
    }

    public func exportURI(_ config: TunnelConfiguration) -> String? {
        let f = config.fields
        guard let uuid = f.string(FieldKey.uuid) else { return nil }
        let password = f.string(FieldKey.password) ?? ""
        var params: [String] = []
        func add(_ key: String, _ value: String?) {
            guard let value, !value.isEmpty else { return }
            let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? value
            params.append("\(key)=\(encoded)")
        }
        add("sni", f.string(FieldKey.sni))
        add("alpn", f.string(FieldKey.alpn))
        add("congestion_control", f.string(FieldKey.congestionControl))
        add("udp_relay_mode", f.string(FieldKey.udpRelayMode))
        if f.bool(FieldKey.allowInsecure) { params.append("allow_insecure=1") }
        let query = params.isEmpty ? "" : "?" + params.joined(separator: "&")
        let name = config.name.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? config.name
        return "tuic://\(uuid):\(password)@\(config.host):\(config.port)\(query)#\(name)"
    }
}
