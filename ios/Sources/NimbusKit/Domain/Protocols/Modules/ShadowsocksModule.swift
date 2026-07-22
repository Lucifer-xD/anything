import Foundation

/// Shadowsocks (SOCKS5 · AEAD). Owns `ss://` in both forms:
///
/// - **SIP002**: `ss://<base64url(method:password)>@host:port/?plugin=…#name`
///   (userinfo may also be the plain `method:password`).
/// - **Legacy**:  `ss://<base64(method:password@host:port)>#name`.
public struct ShadowsocksModule: ProtocolModule {
    public init() {}
    public let kind: ProtocolKind = .shadowsocks
    public let uriSchemes = ["ss"]

    public var fieldSchema: [FieldSection] {
        [
            SchemaKit.general(name: "SG Shadowsocks"),
            SchemaKit.server(host: "sg.ss.stream", port: "8388"),
            FieldSection("AUTHENTICATION", [
                ProtocolField(FieldKey.password, label: "Password", placeholder: "ss password", level: .required, input: .password),
                ProtocolField(FieldKey.cipher, label: "Cipher", level: .required, input: .select(options: ["aes-256-gcm", "chacha20-ietf-poly1305", "2022-blake3-aes-256-gcm"])),
            ]),
            FieldSection("PLUGIN", [
                ProtocolField(FieldKey.plugin, label: "Plugin", level: .optional, input: .select(options: ["none", "obfs-local", "v2ray-plugin"])),
                ProtocolField(FieldKey.pluginOptions, label: "Plugin Options", placeholder: "obfs=tls;host=…", level: .optional),
            ]),
            FieldSection("ADVANCED", [
                ProtocolField(FieldKey.udpOverTCP, label: "UDP over TCP", level: .advanced, input: .toggle(hint: "Relay UDP through TCP")),
                ProtocolField(FieldKey.multiplex, label: "Multiplexing", level: .advanced, input: .toggle(hint: "Reuse connections")),
            ]),
        ]
    }

    public func parse(_ uri: ConfigURI) throws -> TunnelConfiguration? {
        guard uri.scheme == "ss" else { return nil }
        var method: String?
        var password: String?
        var host: String?
        var port: Int?
        let name = uri.fragment

        if let user = uri.user, let h = uri.host {
            // SIP002 — userinfo is method:password (possibly base64url).
            host = h; port = uri.port
            let decoded = user.base64DecodedString() ?? user
            let parts = decoded.split(separator: ":", maxSplits: 1).map(String.init)
            if parts.count == 2 { method = parts[0]; password = parts[1] }
        } else {
            // Legacy — whole body (before #) is base64(method:password@host:port).
            let core = uri.body.split(separator: "#").first.map(String.init) ?? uri.body
            guard let decoded = core.base64DecodedString() else {
                throw NimbusError.parseFailure(scheme: "ss", reason: "body is not base64")
            }
            // method:password@host:port
            let atSplit = decoded.split(separator: "@", maxSplits: 1).map(String.init)
            guard atSplit.count == 2 else {
                throw NimbusError.parseFailure(scheme: "ss", reason: "expected method:password@host:port")
            }
            let cred = atSplit[0].split(separator: ":", maxSplits: 1).map(String.init)
            if cred.count == 2 { method = cred[0]; password = cred[1] }
            if let endpoint = Endpoint(atSplit[1]) { host = endpoint.host; port = endpoint.port }
        }

        guard let method, let password, let host else {
            throw NimbusError.parseFailure(scheme: "ss", reason: "missing method, password or host")
        }
        var fields = ConfigFields()
        fields.set(FieldKey.name, name ?? host)
        fields.set(FieldKey.server, host)
        fields.set(FieldKey.port, port ?? 8388)
        fields.set(FieldKey.cipher, method)
        fields.set(FieldKey.password, password)
        if let plugin = uri.query("plugin") {
            // plugin=obfs-local;obfs=tls;obfs-host=…
            let segments = plugin.split(separator: ";").map(String.init)
            if let first = segments.first { fields.set(FieldKey.plugin, first) }
            if segments.count > 1 { fields.set(FieldKey.pluginOptions, segments.dropFirst().joined(separator: ";")) }
        }
        return TunnelConfiguration(kind: .shadowsocks, fields: fields, metadata: ConfigMetadata(source: .clipboard))
    }

    public func exportURI(_ config: TunnelConfiguration) -> String? {
        let f = config.fields
        guard let method = f.string(FieldKey.cipher), let password = f.string(FieldKey.password) else { return nil }
        let userinfo = "\(method):\(password)".base64URLEncoded()
        let name = config.name.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed) ?? config.name
        var query = ""
        if let plugin = f.string(FieldKey.plugin), plugin != "none" {
            var pluginString = plugin
            if let opts = f.string(FieldKey.pluginOptions), !opts.isEmpty { pluginString += ";" + opts }
            let encoded = pluginString.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? pluginString
            query = "/?plugin=\(encoded)"
        }
        return "ss://\(userinfo)@\(config.host):\(config.port)\(query)#\(name)"
    }
}
