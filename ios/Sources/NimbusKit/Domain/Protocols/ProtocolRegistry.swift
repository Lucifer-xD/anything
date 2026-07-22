import Foundation

/// The single place that knows every protocol module. Look up a module by
/// ``ProtocolKind`` or resolve which module owns a share-link scheme. Adding a
/// protocol is one line here plus its module file.
public final class ProtocolRegistry: @unchecked Sendable {
    public static let shared = ProtocolRegistry()

    private let modules: [ProtocolKind: ProtocolModule]
    private let schemeIndex: [String: ProtocolKind]

    public init(modules: [ProtocolModule] = ProtocolRegistry.defaultModules) {
        var byKind: [ProtocolKind: ProtocolModule] = [:]
        var bySchemes: [String: ProtocolKind] = [:]
        for module in modules {
            byKind[module.kind] = module
            for scheme in module.uriSchemes { bySchemes[scheme.lowercased()] = module.kind }
        }
        self.modules = byKind
        self.schemeIndex = bySchemes
    }

    /// The module for a kind. Every kind is guaranteed a module — unknown kinds
    /// fall back to the generic module so the app never crashes.
    public func module(for kind: ProtocolKind) -> ProtocolModule {
        modules[kind] ?? GenericModule(kind: kind)
    }

    /// The kind that owns a URI scheme, if any.
    public func kind(forScheme scheme: String) -> ProtocolKind? {
        schemeIndex[scheme.lowercased()]
    }

    /// Attempt to parse a share link with whichever module claims its scheme.
    public func parse(_ uri: ConfigURI) throws -> TunnelConfiguration? {
        guard let kind = schemeIndex[uri.scheme] else { return nil }
        return try module(for: kind).parse(uri)
    }

    /// All kinds that have a registered module, in picker order.
    public var registeredKinds: [ProtocolKind] {
        ProtocolKind.allCases.filter { modules[$0] != nil }
    }

    /// The default module set. Order here is the protocol-picker order.
    public static let defaultModules: [ProtocolModule] = [
        WireGuardModule(),
        RealityModule(),
        Hysteria2Module(),
        TUICModule(),
        VLESSModule(),
        VMessModule(),
        TrojanModule(),
        ShadowsocksModule(),
        SSHModule(),
        OpenVPNModule(),
        StunnelModule(),
        SOCKSModule(kind: .socks5),
        SOCKSModule(kind: .socks4),
        HTTPProxyModule(kind: .httpProxy),
        HTTPProxyModule(kind: .httpsProxy),
        WebSocketModule(kind: .websocket),
        WebSocketModule(kind: .websocketTLS),
        DNSTunnelModule(),
    ]
}

/// A minimal fallback module used for any kind without a bespoke implementation.
struct GenericModule: ProtocolModule {
    let kind: ProtocolKind
    var fieldSchema: [FieldSection] {
        [
            SchemaKit.general(name: "New Configuration"),
            SchemaKit.server(host: "host.example.com"),
            FieldSection("AUTHENTICATION", [
                ProtocolField(FieldKey.username, label: "Username", level: .optional),
                ProtocolField(FieldKey.password, label: "Password", level: .required, input: .password),
            ]),
            FieldSection("ADVANCED", [
                ProtocolField(FieldKey.mtu, label: "MTU", placeholder: "1400", level: .advanced, input: .number),
                ProtocolField(FieldKey.compressionLZO, label: "Compression", level: .advanced, input: .toggle(hint: "LZO compression")),
            ]),
        ]
    }
}
