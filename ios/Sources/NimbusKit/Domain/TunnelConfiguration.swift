import Foundation

/// The universal configuration model. Every protocol — WireGuard, Reality,
/// Hysteria2, SSH, … — is represented by the same value type: a ``ProtocolKind``
/// plus a dynamic ``ConfigFields`` bag whose contents are described by that
/// protocol's schema, plus library ``ConfigMetadata``.
///
/// Keeping one model (rather than a class hierarchy per protocol) is what makes
/// the library, search, sync, export and the adaptive editor uniform. Typed,
/// protocol-agnostic accessors (`host`, `port`, `sni`, …) sit on top for the
/// parsers and the tunnel engine.
public struct TunnelConfiguration: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var kind: ProtocolKind
    public var fields: ConfigFields
    public var metadata: ConfigMetadata

    public init(
        id: UUID = UUID(),
        kind: ProtocolKind,
        fields: ConfigFields = ConfigFields(),
        metadata: ConfigMetadata = ConfigMetadata()
    ) {
        self.id = id
        self.kind = kind
        self.fields = fields
        self.metadata = metadata
    }

    // MARK: - Universal accessors (read)

    /// User-facing name; falls back to "New <Protocol>" when unset.
    public var name: String {
        get { fields.string(FieldKey.name, or: "New \(kind.metadata.displayName)") }
        set { fields.set(FieldKey.name, newValue) }
    }

    /// Primary host — reads `server`, then `endpoint`'s host, then `accept`.
    public var host: String {
        if let server = fields.string(FieldKey.server), !server.isEmpty { return server }
        if let endpoint = fields.string(FieldKey.endpoint), let host = Endpoint(endpoint)?.host { return host }
        return fields.string(FieldKey.server, or: "")
    }

    /// Primary port — reads `port`, then `endpoint`'s port, with a protocol default.
    public var port: Int {
        if let port = fields.int(FieldKey.port) { return port }
        if let endpoint = fields.string(FieldKey.endpoint), let port = Endpoint(endpoint)?.port { return port }
        return kind.defaultPort
    }

    /// The transport network (tcp/ws/grpc/…) for the card's second chip.
    public var transportLabel: String {
        (fields.string(FieldKey.network) ?? defaultTransport).uppercased()
    }

    /// SNI / server-name for TLS-bearing protocols.
    public var serverName: String? { fields.string(FieldKey.sni) }

    // MARK: - Convenience

    public var abbreviation: String { kind.metadata.abbreviation }
    public var tintHex: String { kind.metadata.tintHex }

    /// A `host:port` string for display.
    public var endpointDescription: String { "\(host):\(port)" }

    private var defaultTransport: String {
        switch kind {
        case .wireguard, .hysteria2, .tuic: return "udp"
        default: return "tcp"
        }
    }

    // MARK: - Lifecycle helpers

    /// Returns a copy stamped as updated `at`.
    public func touched(at date: Date) -> TunnelConfiguration {
        var copy = self
        copy.metadata.updatedAt = date
        return copy
    }

    /// Returns a duplicate with a fresh id and " Copy" appended to the name.
    public func duplicated(id newID: UUID = UUID(), at date: Date) -> TunnelConfiguration {
        var copy = self
        copy.id = newID
        copy.name = "\(name) Copy"
        copy.metadata.isPinned = false
        copy.metadata.createdAt = date
        copy.metadata.updatedAt = date
        return copy
    }

    /// Validates against the protocol module. Empty result == valid.
    public func validate() -> [ValidationIssue] {
        ProtocolRegistry.shared.module(for: kind).validate(self)
    }
}

public extension ProtocolKind {
    /// Sensible default port used when a config omits one.
    var defaultPort: Int {
        switch self {
        case .wireguard: return 51820
        case .ssh: return 22
        case .httpProxy, .httpsProxy: return 8080
        case .socks4, .socks5: return 1080
        case .shadowsocks: return 8388
        case .dnsTunnel: return 53
        default: return 443
        }
    }
}
