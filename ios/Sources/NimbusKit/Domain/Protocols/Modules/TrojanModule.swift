import Foundation

/// Trojan (TLS, looks like HTTPS). Owns `trojan://`.
///
/// Grammar: `trojan://<password>@<host>:<port>?<params>#<name>`
/// Params: `sni` `type`(network) `security` `alpn` `fp` `path` `host` `allowInsecure`.
public struct TrojanModule: ProtocolModule {
    public init() {}
    public let kind: ProtocolKind = .trojan
    public let uriSchemes = ["trojan"]

    public var fieldSchema: [FieldSection] {
        [
            SchemaKit.general(name: "Work — Trojan"),
            SchemaKit.server(host: "edge.corp.dev"),
            FieldSection("AUTHENTICATION", [
                ProtocolField(FieldKey.password, label: "Password", placeholder: "trojan password", level: .required, input: .password),
            ]),
            FieldSection("TLS", [
                ProtocolField(FieldKey.sni, label: "SNI", placeholder: "corp.dev", level: .required),
                ProtocolField(FieldKey.alpn, label: "ALPN", level: .optional, input: .select(options: ["h2", "http/1.1", "h2,http/1.1"])),
                ProtocolField(FieldKey.fingerprint, label: "Fingerprint", level: .optional, input: .select(options: ["chrome", "firefox", "safari"])),
                ProtocolField(FieldKey.allowInsecure, label: "Allow Insecure", level: .advanced, input: .toggle(hint: "Skip cert verification")),
            ]),
            FieldSection("TRANSPORT", [
                ProtocolField(FieldKey.network, label: "Network", level: .required, input: .select(options: ["tcp", "ws", "grpc"])),
                ProtocolField(FieldKey.path, label: "Path", placeholder: "/", level: .optional),
                ProtocolField(FieldKey.hostHeader, label: "Host Header", level: .optional),
            ]),
        ]
    }

    public func parse(_ uri: ConfigURI) throws -> TunnelConfiguration? {
        guard uri.scheme == "trojan" else { return nil }
        guard let password = uri.user, let host = uri.host else {
            throw NimbusError.parseFailure(scheme: "trojan", reason: "missing password or host")
        }
        var fields = ConfigFields()
        fields.set(FieldKey.name, uri.fragment ?? host)
        fields.set(FieldKey.server, host)
        fields.set(FieldKey.port, uri.port ?? 443)
        fields.set(FieldKey.password, password)
        fields.setIfPresent(FieldKey.sni, uri.query("sni") ?? uri.query("peer") ?? uri.query("host"))
        fields.setIfPresent(FieldKey.alpn, uri.query("alpn"))
        fields.setIfPresent(FieldKey.fingerprint, uri.query("fp"))
        fields.set(FieldKey.network, uri.query("type") ?? "tcp")
        fields.setIfPresent(FieldKey.path, uri.query("path"))
        fields.setIfPresent(FieldKey.hostHeader, uri.query("host"))
        if uri.query("allowInsecure") == "1" || uri.query("insecure") == "1" {
            fields.set(FieldKey.allowInsecure, true)
        }
        return TunnelConfiguration(kind: .trojan, fields: fields, metadata: ConfigMetadata(source: .clipboard))
    }

    public func exportURI(_ config: TunnelConfiguration) -> String? {
        let f = config.fields
        guard let password = f.string(FieldKey.password) else { return nil }
        var params: [String] = []
        func add(_ key: String, _ value: String?) {
            guard let value, !value.isEmpty else { return }
            let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? value
            params.append("\(key)=\(encoded)")
        }
        add("sni", f.string(FieldKey.sni))
        add("type", f.string(FieldKey.network))
        add("alpn", f.string(FieldKey.alpn))
        add("fp", f.string(FieldKey.fingerprint))
        add("path", f.string(FieldKey.path))
        add("host", f.string(FieldKey.hostHeader))
        if f.bool(FieldKey.allowInsecure) { params.append("allowInsecure=1") }
        let query = params.isEmpty ? "" : "?" + params.joined(separator: "&")
        let name = config.name.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? config.name
        return "trojan://\(password)@\(config.host):\(config.port)\(query)#\(name)"
    }
}
