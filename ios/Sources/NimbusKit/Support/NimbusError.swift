import Foundation

/// The single error domain surfaced by NimbusKit. Every throwing API in the core
/// funnels into one of these cases so the UI can present a consistent, localized
/// message and, where useful, a recovery suggestion.
public enum NimbusError: Error, Equatable, Sendable {
    /// A share-link / config string could not be parsed. `scheme` is the URI
    /// scheme (e.g. `vless`) when known.
    case parseFailure(scheme: String?, reason: String)
    /// A configuration failed validation before save or connect.
    case validation([ValidationIssue])
    /// A required field was missing for the operation.
    case missingField(key: String, protocol: ProtocolKind)
    /// Import produced no usable configurations.
    case emptyImport(reason: String)
    /// The requested configuration / folder / server does not exist.
    case notFound(id: String)
    /// Persistence (read/write/encode/decode) failed.
    case storage(reason: String)
    /// The tunnel engine rejected or aborted a session.
    case tunnel(reason: String)
    /// Cloud sync failed (network, auth, or conflict that could not be resolved).
    case sync(reason: String)
    /// A cryptographic operation (encrypt/decrypt/sign) failed.
    case crypto(reason: String)
    /// The feature requires an Apple framework unavailable in this build.
    case unsupportedPlatform(feature: String)
}

extension NimbusError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .parseFailure(scheme, reason):
            let prefix = scheme.map { "Couldn’t read \($0):// link" } ?? "Couldn’t read configuration"
            return "\(prefix) — \(reason)"
        case let .validation(issues):
            return issues.first?.message ?? "The configuration has invalid fields."
        case let .missingField(key, proto):
            return "\(proto.metadata.displayName) requires “\(key)”."
        case let .emptyImport(reason):
            return "Nothing to import — \(reason)"
        case let .notFound(id):
            return "That item no longer exists (\(id))."
        case let .storage(reason):
            return "Storage error — \(reason)"
        case let .tunnel(reason):
            return "Tunnel error — \(reason)"
        case let .sync(reason):
            return "Sync error — \(reason)"
        case let .crypto(reason):
            return "Encryption error — \(reason)"
        case let .unsupportedPlatform(feature):
            return "“\(feature)” isn’t available on this platform."
        }
    }
}
