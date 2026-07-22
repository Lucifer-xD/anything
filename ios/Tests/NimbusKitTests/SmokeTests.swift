import XCTest
@testable import NimbusKit

/// Minimal smoke test to keep the package manifest valid while the full suite is
/// authored. Real coverage lives in the sibling test files.
final class SmokeTests: XCTestCase {
    func testEveryKindHasMetadataAndSchema() {
        for kind in ProtocolKind.allCases {
            XCTAssertFalse(kind.metadata.displayName.isEmpty, "\(kind) missing display name")
            XCTAssertFalse(kind.fieldSchema.isEmpty, "\(kind) missing schema")
            // Every schema must at least ask for a name.
            XCTAssertTrue(kind.fieldSchema.allFields.contains { $0.key == FieldKey.name }, "\(kind) schema has no name field")
        }
    }
}
