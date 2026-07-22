import Foundation

/// VLESS (and, via `security=reality`, VLESS + Reality). Owns the `vless://`
/// scheme. When a link declares `security=reality` the parsed configuration is
/// tagged as ``ProtocolKind/reality`` so the editor shows the Reality schema.
///
/// Grammar: `vless://<uuid>@<host>:<port>?<params>#<name>`
/// Params: `type`(network) `security` `encryption` `flow` `sni` `fp` `pbk`
/// `sid` `spx` `path` `host` `serviceName` `alpn` `mode`.
public struct VLESSModule: ProtocolModule {
    public init() {}
    public let kind: ProtocolKind = .vless
    public let uriSchemes = ["vless"]

    public var fieldSchema: [FieldSection] {
        [
            SchemaKit.general(name: "VLESS WS"),
            SchemaKit.server(host: "edge.example.io"),
            FieldSection("AUTHENTICATION", [
                ProtocolField(FieldKey.uuid, label: "UUID", placeholder: "xxxxxxxx-xxxx-…", level: .required),
                ProtocolField(FieldKey.flow, label: "Flow", level: .optional, input: .select(options: ["none", "xtls-rprx-vision"])),
            ]),
            FieldSection("TLS", [
                ProtocolField(FieldKey.security, label: "Security", level: .required, input: .select(options: ["tls", "reality", "none"])),
                ProtocolField(FieldKey.sni, label: "SNI (Server Name)", placeholder: "example.com", level: .required),
                ProtocolField(FieldKey.fingerprint, label: "Fingerprint", level: .optional, input: .select(options: ["chrome", "firefox", "safari", "random"])),
                ProtocolField(FieldKey.realityPublicKey, label: "Reality Public Key", placeholder: "reality public key", level: .optional, input: .password),
                ProtocolField(FieldKey.shortID, label: "Short ID", placeholder: "0123abcd", level: .optional),
                ProtocolField(FieldKey.alpn, label: "ALPN", level: .optional, input: .select(options: ["h2", "http/1.1"])),
            ]),
            FieldSection("TRANSPORT", [
                ProtocolField(FieldKey.network, label: "Network", level: .required, input: .select(options: ["tcp", "ws", "grpc", "xhttp", "h2"])),
                ProtocolField(FieldKey.path, label: "Path", placeholder: "/", level: .optional),
                ProtocolField(FieldKey.hostHeader, label: "Host Header", level: .optional),
            ]),
        ]
    }

    public func parse(_ uri: ConfigURI) throws -> TunnelConfiguration? {
        guard uri.scheme == "vless" else { return nil }
        guard let uuid = uri.user, let host = uri.host else {
            throw NimbusError.parseFailure(scheme: "vless", reason: "missing uuid or host")
        }
        let security = uri.query("security") ?? "none"
        let resolvedKind: ProtocolKind = (security == "reality") ? .reality : .vless

        var fields = ConfigFields()
        fields.set(FieldKey.name, uri.fragment ?? "\(host)")
        fields.set(FieldKey.server, host)
        fields.set(FieldKey.port, uri.port ?? 443)
        fields.set(FieldKey.uuid, uuid)
        fields.setIfPresent(FieldKey.flow, uri.query("flow"))
        fields.set(FieldKey.security, security)
        fields.setIfPresent(FieldKey.sni, uri.query("sni") ?? uri.query("host"))
        fields.setIfPresent(FieldKey.fingerprint, uri.query("fp"))
        fields.setIfPresent(FieldKey.realityPublicKey, uri.query("pbk"))
        fields.setIfPresent(FieldKey.shortID, uri.query("sid"))
        fields.setIfPresent(FieldKey.spiderX, uri.query("spx"))
        fields.setIfPresent(FieldKey.alpn, uri.query("alpn"))
        fields.set(FieldKey.network, uri.query("type") ?? "tcp")
        fields.setIfPresent(FieldKey.path, uri.query("path") ?? uri.query("serviceName"))
        fields.setIfPresent(FieldKey.hostHeader, uri.query("host"))

        var metadata = ConfigMetadata(group: "Subscriptions", source: .clipboard)
        metadata.group = "Personal"
        return TunnelConfiguration(kind: resolvedKind, fields: fields, metadata: metadata)
    }

    public func exportURI(_ config: TunnelConfiguration) -> String? {
        let f = config.fields
        guard let uuid = f.string(FieldKey.uuid) else { return nil }
        var params: [String] = []
        func add(_ key: String, _ value: String?) {
            guard let value, !value.isEmpty else { return }
            let encoded = value.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? value
            params.append("\(key)=\(encoded)")
        }
        add("type", f.string(FieldKey.network))
        add("security", f.string(FieldKey.security))
        add("flow", f.string(FieldKey.flow))
        add("sni", f.string(FieldKey.sni))
        add("fp", f.string(FieldKey.fingerprint))
        add("pbk", f.string(FieldKey.realityPublicKey))
        add("sid", f.string(FieldKey.shortID))
        add("spx", f.string(FieldKey.spiderX))
        add("path", f.string(FieldKey.path))
        add("host", f.string(FieldKey.hostHeader))
        add("alpn", f.string(FieldKey.alpn))
        let query = params.isEmpty ? "" : "?" + params.joined(separator: "&")
        let name = config.name.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? config.name
        return "vless://\(uuid)@\(config.host):\(config.port)\(query)#\(name)"
    }
}
