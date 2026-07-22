import Foundation

/// The contract every protocol implements. Each protocol is an *independent
/// module* (its own file under `Protocols/Modules/`) that owns:
///
/// - the adaptive editor **schema** (which fields to show),
/// - **parsing** its share-link form(s) into a ``TunnelConfiguration``,
/// - **exporting** a config back to a share link,
/// - **validation** before save/connect,
/// - **session planning** — turning a config into an engine-ready ``SessionPlan``.
///
/// Adding a protocol means adding one file and registering it in
/// ``ProtocolRegistry`` — nothing else in the app changes. Default
/// implementations cover the common cases so a simple module only overrides
/// `fieldSchema`.
public protocol ProtocolModule {
    var kind: ProtocolKind { get }

    /// The dynamic editor schema (sections → fields).
    var fieldSchema: [FieldSection] { get }

    /// URI schemes this module claims (e.g. `["vless"]`). Empty ⇒ not importable
    /// from a share link.
    var uriSchemes: [String] { get }

    /// Parse a share link into a configuration, or `nil` if it isn't ours.
    func parse(_ uri: ConfigURI) throws -> TunnelConfiguration?

    /// Serialize a configuration back into a share link, or `nil` if unsupported.
    func exportURI(_ config: TunnelConfiguration) -> String?

    /// Validate a configuration. Empty ⇒ valid.
    func validate(_ config: TunnelConfiguration) -> [ValidationIssue]

    /// Resolve a configuration into an engine-ready session plan.
    func makeSessionPlan(_ config: TunnelConfiguration) throws -> SessionPlan
}

// MARK: - Default implementations

public extension ProtocolModule {
    var uriSchemes: [String] { [] }

    func parse(_ uri: ConfigURI) throws -> TunnelConfiguration? { nil }

    func exportURI(_ config: TunnelConfiguration) -> String? { nil }

    /// Generic validation: every `.required` field in the schema must be present
    /// and non-empty.
    func validate(_ config: TunnelConfiguration) -> [ValidationIssue] {
        var issues: [ValidationIssue] = []
        for field in fieldSchema.allFields where field.level == .required {
            let value = config.fields[field.key]
            if value == nil || value?.isEmpty == true {
                issues.append(.required(field.key, field.label))
            }
        }
        return issues
    }

    /// Generic session plan: copies universal networking fields and forwards
    /// every stored field to the core as a string parameter.
    func makeSessionPlan(_ config: TunnelConfiguration) throws -> SessionPlan {
        let dns = (config.fields.string(FieldKey.dns) ?? "1.1.1.1, 1.0.0.1")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        var parameters: [String: String] = [:]
        for key in config.fields.keys {
            if let value = config.fields[key]?.stringValue { parameters[key] = value }
        }
        return SessionPlan(
            configID: config.id,
            displayName: config.name,
            kind: config.kind,
            core: config.kind.core,
            host: config.host,
            port: config.port,
            dnsServers: dns.isEmpty ? ["1.1.1.1", "1.0.0.1"] : dns,
            mtu: config.fields.int(FieldKey.mtu),
            parameters: parameters
        )
    }
}

// MARK: - Shared schema fragments

/// Reusable schema pieces so modules stay DRY and consistent.
public enum SchemaKit {
    public static let groupOptions = ["Personal", "Work", "Gaming", "Subscriptions"]

    /// GENERAL section (name + group) present on every protocol.
    public static func general(name placeholder: String) -> FieldSection {
        FieldSection("GENERAL", [
            ProtocolField(FieldKey.name, label: "Configuration Name", placeholder: placeholder, level: .required),
            ProtocolField(FieldKey.group, label: "Group", level: .optional, input: .select(options: groupOptions)),
        ])
    }

    /// SERVER section (address + port).
    public static func server(host: String, port: String = "443") -> FieldSection {
        FieldSection("SERVER", [
            ProtocolField(FieldKey.server, label: "Address", placeholder: host, level: .required),
            ProtocolField(FieldKey.port, label: "Port", placeholder: port, level: .required, input: .number),
        ])
    }
}
