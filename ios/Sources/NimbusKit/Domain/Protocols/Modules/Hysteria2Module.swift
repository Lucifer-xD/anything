import Foundation

/// Hysteria2 (QUIC, great on lossy networks). Owns `hysteria2://` and `hy2://`.
///
/// Grammar: `hysteria2://<auth>@<host>:<port>?<params>#<name>`
/// Params: `sni` `insecure` `obfs` `obfs-password` `up` `down` `pinSHA256`.
public struct Hysteria2Module: ProtocolModule {
    public init() {}
    public let kind: ProtocolKind = .hysteria2
    public let uriSchemes = ["hysteria2", "hy2"]

    public var fieldSchema: [FieldSection] {
        [
            SchemaKit.general(name: "Tokyo Gaming"),
            SchemaKit.server(host: "jp.hy2.gg", port: "8443"),
            FieldSection("AUTHENTICATION", [
                ProtocolField(FieldKey.auth, label: "Auth / Password", placeholder: "shared secret", level: .required, input: .password),
            ]),
            FieldSection("TLS", [
                ProtocolField(FieldKey.sni, label: "SNI", placeholder: "example.com", level: .required),
                ProtocolField(FieldKey.allowInsecure, label: "Allow Insecure", level: .advanced, input: .toggle(hint: "Skip cert verification")),
                ProtocolField(FieldKey.pinnedSHA256, label: "Pinned SHA-256", placeholder: "certificate hash", level: .experimental),
            ]),
            FieldSection("BANDWIDTH", [
                ProtocolField(FieldKey.up, label: "Up Mbps", placeholder: "50", level: .optional, input: .number),
                ProtocolField(FieldKey.down, label: "Down Mbps", placeholder: "200", level: .optional, input: .number),
            ]),
            FieldSection("OBFUSCATION", [
                ProtocolField(FieldKey.obfs, label: "Type", level: .optional, input: .select(options: ["none", "salamander"])),
                ProtocolField(FieldKey.obfsPassword, label: "Obfs Password", level: .optional, input: .password),
            ]),
        ]
    }

    public func parse(_ uri: ConfigURI) throws -> TunnelConfiguration? {
        guard uri.scheme == "hysteria2" || uri.scheme == "hy2" else { return nil }
        guard let host = uri.host else {
            throw NimbusError.parseFailure(scheme: uri.scheme, reason: "missing host")
        }
        var fields = ConfigFields()
        fields.set(FieldKey.name, uri.fragment ?? host)
        fields.set(FieldKey.server, host)
        fields.set(FieldKey.port, uri.port ?? 443)
        fields.setIfPresent(FieldKey.auth, uri.user)
        fields.setIfPresent(FieldKey.sni, uri.query("sni") ?? uri.query("peer"))
        if uri.query("insecure") == "1" { fields.set(FieldKey.allowInsecure, true) }
        fields.setIfPresent(FieldKey.pinnedSHA256, uri.query("pinSHA256"))
        fields.setIfPresent(FieldKey.up, uri.query("up"))
        fields.setIfPresent(FieldKey.down, uri.query("down"))
        fields.setIfPresent(FieldKey.obfs, uri.query("obfs"))
        fields.setIfPresent(FieldKey.obfsPassword, uri.query("obfs-password"))
        return TunnelConfiguration(kind: .hysteria2, fields: fields, metadata: ConfigMetadata(source: .clipboard))
    }

    public func exportURI(_ config: TunnelConfiguration) -> String? {
        let f = config.fields
        let auth = f.string(FieldKey.auth) ?? ""
        var params: [String] = []
        func add(_ key: String, _ value: String?) {
            guard let value, !value.isEmpty else { return }
            let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? value
            params.append("\(key)=\(encoded)")
        }
        add("sni", f.string(FieldKey.sni))
        if f.bool(FieldKey.allowInsecure) { params.append("insecure=1") }
        add("obfs", f.string(FieldKey.obfs))
        add("obfs-password", f.string(FieldKey.obfsPassword))
        let query = params.isEmpty ? "" : "?" + params.joined(separator: "&")
        let name = config.name.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? config.name
        let credential = auth.isEmpty ? "" : "\(auth)@"
        return "hysteria2://\(credential)\(config.host):\(config.port)\(query)#\(name)"
    }
}
