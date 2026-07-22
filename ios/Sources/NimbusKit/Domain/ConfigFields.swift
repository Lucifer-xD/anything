import Foundation

/// The dynamic value bag backing a configuration. Values are keyed by schema
/// field key (see ``FieldKey``) and boxed in ``ConfigValue``. Typed accessors
/// give parsers and the engine ergonomic, non-optional-chaining reads/writes
/// while the editor can bind to arbitrary keys the schema declares.
public struct ConfigFields: Codable, Equatable, Sendable {
    public private(set) var storage: [String: ConfigValue]

    public init(_ storage: [String: ConfigValue] = [:]) {
        self.storage = storage
    }

    // MARK: Subscript / raw access

    public subscript(key: String) -> ConfigValue? {
        get { storage[key] }
        set { storage[key] = newValue }
    }

    public var keys: [String] { Array(storage.keys) }
    public var isEmpty: Bool { storage.isEmpty }

    // MARK: Typed readers

    public func string(_ key: String) -> String? { storage[key]?.stringValue }
    public func int(_ key: String) -> Int? { storage[key]?.intValue }
    public func bool(_ key: String) -> Bool { storage[key]?.boolValue ?? false }

    /// Non-optional string with a fallback (handy for building endpoints).
    public func string(_ key: String, or fallback: String) -> String {
        let value = storage[key]?.stringValue
        return (value?.isEmpty == false) ? value! : fallback
    }

    // MARK: Typed writers (chainable via mutation)

    public mutating func set(_ key: String, _ value: String?) {
        guard let value, !value.isEmpty else { storage[key] = nil; return }
        storage[key] = .string(value)
    }

    public mutating func set(_ key: String, _ value: Int?) {
        guard let value else { storage[key] = nil; return }
        storage[key] = .int(value)
    }

    public mutating func set(_ key: String, _ value: Bool) {
        storage[key] = .bool(value)
    }

    public mutating func setIfPresent(_ key: String, _ value: String?) {
        guard let value, !value.isEmpty else { return }
        storage[key] = .string(value)
    }

    /// Fill any missing keys from `defaults` without overwriting existing values.
    public mutating func applyDefaults(_ defaults: [String: ConfigValue]) {
        for (key, value) in defaults where storage[key] == nil {
            storage[key] = value
        }
    }

    /// A merged copy — `other` wins on conflicts.
    public func merging(_ other: ConfigFields) -> ConfigFields {
        ConfigFields(storage.merging(other.storage) { _, new in new })
    }
}

extension ConfigFields: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, ConfigValue)...) {
        self.init(Dictionary(uniqueKeysWithValues: elements))
    }
}
