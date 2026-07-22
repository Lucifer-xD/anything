import Foundation

/// A single problem found while validating a configuration. Severity lets the UI
/// distinguish "won't save" (error) from "will probably fail to connect"
/// (warning) from "heads up" (info).
public struct ValidationIssue: Equatable, Sendable, Identifiable {
    public enum Severity: Int, Comparable, Sendable {
        case info = 0, warning = 1, error = 2
        public static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    /// The field key this issue concerns, if field-specific.
    public let fieldKey: String?
    public let severity: Severity
    public let message: String

    public var id: String { "\(fieldKey ?? "_")-\(severity.rawValue)-\(message)" }

    public init(fieldKey: String? = nil, severity: Severity = .error, message: String) {
        self.fieldKey = fieldKey
        self.severity = severity
        self.message = message
    }

    public static func required(_ key: String, _ label: String) -> ValidationIssue {
        ValidationIssue(fieldKey: key, severity: .error, message: "\(label) is required.")
    }
}

public extension Array where Element == ValidationIssue {
    var hasErrors: Bool { contains { $0.severity == .error } }
    var errors: [ValidationIssue] { filter { $0.severity == .error } }
}
