import Foundation

/// A single, type-tagged value stored for a configuration field.
///
/// The protocol editor is *dynamic* — the set of fields shown depends on the
/// selected protocol (see ``ProtocolModule/fieldSchema``). To keep the model
/// flexible while staying `Codable` and `Equatable`, every field value is boxed
/// in a `ConfigValue` and stored in ``ConfigFields`` keyed by the schema field
/// key. Parsers and the tunnel engine read strongly-typed values back out via
/// the accessors on ``ConfigFields``.
public enum ConfigValue: Codable, Equatable, Hashable, Sendable {
    case string(String)
    case int(Int)
    case bool(Bool)

    // MARK: Convenience readers

    public var stringValue: String? {
        switch self {
        case let .string(value): return value
        case let .int(value): return String(value)
        case let .bool(value): return value ? "true" : "false"
        }
    }

    public var intValue: Int? {
        switch self {
        case let .int(value): return value
        case let .string(value): return Int(value.trimmingCharacters(in: .whitespaces))
        case let .bool(value): return value ? 1 : 0
        }
    }

    public var boolValue: Bool? {
        switch self {
        case let .bool(value): return value
        case let .int(value): return value != 0
        case let .string(value):
            switch value.lowercased() {
            case "1", "true", "yes", "on": return true
            case "0", "false", "no", "off", "": return false
            default: return nil
            }
        }
    }

    /// `true` when the value carries no meaningful content (empty string).
    public var isEmpty: Bool {
        switch self {
        case let .string(value): return value.isEmpty
        default: return false
        }
    }

    // MARK: Codable (compact single-value encoding)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Int.self) {
            self = .int(value)
        } else {
            self = .string(try container.decode(String.self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value): try container.encode(value)
        case let .int(value): try container.encode(value)
        case let .bool(value): try container.encode(value)
        }
    }
}

extension ConfigValue: ExpressibleByStringLiteral,
                       ExpressibleByIntegerLiteral,
                       ExpressibleByBooleanLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
    public init(integerLiteral value: Int) { self = .int(value) }
    public init(booleanLiteral value: Bool) { self = .bool(value) }
}
