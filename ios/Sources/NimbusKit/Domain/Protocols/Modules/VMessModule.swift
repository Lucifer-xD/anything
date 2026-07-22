import Foundation

/// VMess (V2Ray). Owns `vmess://`, whose body is base64-encoded JSON.
///
/// JSON keys: `v` `ps`(name) `add`(server) `port` `id`(uuid) `aid`(alterId)
/// `scy`(cipher) `net` `type`(header) `host` `path` `tls` `sni` `alpn` `fp`.
public struct VMessModule: ProtocolModule {
    public init() {}
    public let kind: ProtocolKind = .vmess
    public let uriSchemes = ["vmess"]

    public var fieldSchema: [FieldSection] {
        [
            SchemaKit.general(name: "US VMess WS"),
            SchemaKit.server(host: "us.v2.cloud"),
            FieldSection("AUTHENTICATION", [
                ProtocolField(FieldKey.uuid, label: "UUID", placeholder: "xxxxxxxx-xxxx-…", level: .required),
                ProtocolField(FieldKey.alterID, label: "AlterId", placeholder: "0", level: .optional, input: .number),
                ProtocolField(FieldKey.cipher, label: "Security", level: .optional, input: .select(options: ["auto", "aes-128-gcm", "chacha20-poly1305", "none"])),
            ]),
            FieldSection("TLS", [
                ProtocolField(FieldKey.security, label: "Security", level: .required, input: .select(options: ["tls", "none"])),
                ProtocolField(FieldKey.sni, label: "SNI (Server Name)", placeholder: "example.com", level: .required),
                ProtocolField(FieldKey.alpn, label: "ALPN", level: .optional, input: .select(options: ["h2", "http/1.1", "h2,http/1.1"])),
                ProtocolField(FieldKey.fingerprint, label: "Fingerprint", level: .optional, input: .select(options: ["chrome", "firefox", "safari", "random"])),
            ]),
            FieldSection("TRANSPORT", [
                ProtocolField(FieldKey.network, label: "Network", level: .required, input: .select(options: ["tcp", "ws", "grpc", "h2", "kcp"])),
                ProtocolField(FieldKey.path, label: "Path", placeholder: "/ray", level: .optional),
                ProtocolField(FieldKey.hostHeader, label: "Host Header", placeholder: "cdn.example.com", level: .optional),
            ]),
            FieldSection("ADVANCED", [
                ProtocolField(FieldKey.multiplex, label: "Multiplexing", level: .advanced, input: .toggle(hint: "Reuse a single connection")),
            ]),
        ]
    }

    public func parse(_ uri: ConfigURI) throws -> TunnelConfiguration? {
        guard uri.scheme == "vmess" else { return nil }
        guard let json = uri.body.base64DecodedData(),
              let object = try? JSONSerialization.jsonObject(with: json) as? [String: Any] else {
            throw NimbusError.parseFailure(scheme: "vmess", reason: "body is not base64 JSON")
        }
        func str(_ key: String) -> String? {
            if let s = object[key] as? String { return s.isEmpty ? nil : s }
            if let n = object[key] as? NSNumber { return n.stringValue }
            return nil
        }
        guard let uuid = str("id"), let add = str("add") else {
            throw NimbusError.parseFailure(scheme: "vmess", reason: "missing id or add")
        }
        var fields = ConfigFields()
        fields.set(FieldKey.name, str("ps") ?? add)
        fields.set(FieldKey.server, add)
        fields.set(FieldKey.port, Int(str("port") ?? "443") ?? 443)
        fields.set(FieldKey.uuid, uuid)
        fields.set(FieldKey.alterID, Int(str("aid") ?? "0") ?? 0)
        fields.setIfPresent(FieldKey.cipher, str("scy"))
        let tls = str("tls")
        fields.set(FieldKey.security, (tls == "tls" || tls == "reality") ? (tls ?? "none") : "none")
        fields.setIfPresent(FieldKey.sni, str("sni") ?? str("host"))
        fields.setIfPresent(FieldKey.alpn, str("alpn"))
        fields.setIfPresent(FieldKey.fingerprint, str("fp"))
        fields.set(FieldKey.network, str("net") ?? "tcp")
        fields.setIfPresent(FieldKey.path, str("path"))
        fields.setIfPresent(FieldKey.hostHeader, str("host"))
        return TunnelConfiguration(kind: .vmess, fields: fields, metadata: ConfigMetadata(source: .clipboard))
    }

    public func exportURI(_ config: TunnelConfiguration) -> String? {
        let f = config.fields
        guard let uuid = f.string(FieldKey.uuid) else { return nil }
        let object: [String: Any] = [
            "v": "2",
            "ps": config.name,
            "add": config.host,
            "port": String(config.port),
            "id": uuid,
            "aid": String(f.int(FieldKey.alterID) ?? 0),
            "scy": f.string(FieldKey.cipher) ?? "auto",
            "net": f.string(FieldKey.network) ?? "tcp",
            "type": "none",
            "host": f.string(FieldKey.hostHeader) ?? "",
            "path": f.string(FieldKey.path) ?? "",
            "tls": (f.string(FieldKey.security) == "tls") ? "tls" : "",
            "sni": f.string(FieldKey.sni) ?? "",
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else { return nil }
        return "vmess://" + data.base64EncodedString()
    }
}
