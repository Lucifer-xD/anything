import Foundation

/// Importance/visibility tier for a field, driving the colored badge in the
/// editor (Required = amber, Advanced = accent, Experimental = purple, Optional =
/// none). Mirrors the `lvl` tokens in the imported design.
public enum FieldLevel: String, Codable, CaseIterable, Sendable {
    case required = "req"
    case optional = "opt"
    case advanced = "adv"
    case experimental = "exp"

    public var badgeTitle: String? {
        switch self {
        case .required: return "REQUIRED"
        case .advanced: return "ADVANCED"
        case .experimental: return "EXPERIMENTAL"
        case .optional: return nil
        }
    }
}

/// How a field is rendered and edited.
public enum FieldInput: Equatable, Sendable {
    case text
    case number
    case password
    /// Long multi-line input (keys, certificates, custom payloads).
    case multiline
    /// A single choice from `options`; the first option is the default.
    case select(options: [String])
    /// A boolean switch; `hint` describes what it does.
    case toggle(hint: String)

    public var isSecure: Bool { if case .password = self { return true }; return false }
}

/// One editable field inside a protocol's schema.
public struct ProtocolField: Identifiable, Equatable, Sendable {
    /// Stable key used for the value in ``ConfigFields`` (matches `FieldKey`).
    public let key: String
    public let label: String
    public let placeholder: String
    public let level: FieldLevel
    public let input: FieldInput
    /// Optional default applied when the field is first materialized.
    public let defaultValue: ConfigValue?

    public var id: String { key }

    public init(
        _ key: String,
        label: String,
        placeholder: String = "",
        level: FieldLevel = .optional,
        input: FieldInput = .text,
        default defaultValue: ConfigValue? = nil
    ) {
        self.key = key
        self.label = label
        self.placeholder = placeholder
        self.level = level
        self.input = input
        self.defaultValue = defaultValue
    }

    /// The effective default: an explicit default, or the first option of a
    /// `select`, otherwise `nil`.
    public var resolvedDefault: ConfigValue? {
        if let defaultValue { return defaultValue }
        if case let .select(options) = input, let first = options.first { return .string(first) }
        return nil
    }
}

/// A titled group of fields (e.g. "SERVER", "TLS", "TRANSPORT").
public struct FieldSection: Identifiable, Equatable, Sendable {
    public let title: String
    public let fields: [ProtocolField]
    public var id: String { title }

    public init(_ title: String, _ fields: [ProtocolField]) {
        self.title = title
        self.fields = fields
    }
}

public extension Array where Element == FieldSection {
    /// Every field across all sections, flattened.
    var allFields: [ProtocolField] { flatMap(\.fields) }

    /// Field keys that are `.required`.
    var requiredKeys: [String] { allFields.filter { $0.level == .required }.map(\.key) }

    /// The seed value map for a brand-new configuration built from this schema.
    var defaultValues: [String: ConfigValue] {
        var out: [String: ConfigValue] = [:]
        for field in allFields where field.resolvedDefault != nil {
            out[field.key] = field.resolvedDefault
        }
        return out
    }
}
