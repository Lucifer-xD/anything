import XCTest
@testable import NimbusKit

final class ModelTests: XCTestCase {
    func testConfigValueCodableRoundTrip() throws {
        let values: [ConfigValue] = [.string("hello"), .int(42), .bool(true)]
        for value in values {
            let data = try JSONEncoder().encode(value)
            let decoded = try JSONDecoder().decode(ConfigValue.self, from: data)
            XCTAssertEqual(value, decoded)
        }
    }

    func testConfigFieldsTypedAccessors() {
        var fields = ConfigFields()
        fields.set(FieldKey.server, "host.io")
        fields.set(FieldKey.port, 443)
        fields.set(FieldKey.multiplex, true)
        XCTAssertEqual(fields.string(FieldKey.server), "host.io")
        XCTAssertEqual(fields.int(FieldKey.port), 443)
        XCTAssertTrue(fields.bool(FieldKey.multiplex))
        // Setting empty string clears the value.
        fields.set(FieldKey.server, "")
        XCTAssertNil(fields.string(FieldKey.server))
        XCTAssertEqual(fields.string(FieldKey.server, or: "fallback"), "fallback")
    }

    func testConfigFieldsApplyDefaults() {
        var fields = ConfigFields([FieldKey.network: .string("ws")])
        fields.applyDefaults([FieldKey.network: .string("tcp"), FieldKey.security: .string("tls")])
        XCTAssertEqual(fields.string(FieldKey.network), "ws", "existing value must not be overwritten")
        XCTAssertEqual(fields.string(FieldKey.security), "tls")
    }

    func testEndpointParsing() {
        XCTAssertEqual(Endpoint("host.io:443"), Endpoint(host: "host.io", port: 443))
        XCTAssertEqual(Endpoint("[2001:db8::1]:51820"), Endpoint(host: "2001:db8::1", port: 51820))
        XCTAssertEqual(Endpoint("example.com")?.port, 0)
        XCTAssertEqual(Endpoint("2001:db8::1")?.host, "2001:db8::1")
        XCTAssertEqual(Endpoint("2001:db8::1")?.port, 0)
        XCTAssertNil(Endpoint(""))
    }

    func testByteFormat() {
        XCTAssertEqual(ByteFormat.short(0), "0 B")
        XCTAssertEqual(ByteFormat.short(1536), "1.5 KB")
        XCTAssertEqual(ByteFormat.short(12_884_901_888), "12.0 GB")
        XCTAssertEqual(ByteFormat.short(13_314_398_617), "12.4 GB")
        XCTAssertEqual(ByteFormat.rate(bitsPerSecond: 187_400_000), "187.4 Mbps")
        XCTAssertEqual(ByteFormat.duration(3_662), "1:01:02")
        XCTAssertEqual(ByteFormat.duration(62), "01:02")
    }

    func testLogFilterMatching() {
        XCTAssertTrue(LogFilter.all.matches(.error))
        XCTAssertTrue(LogFilter.errors.matches(.error))
        XCTAssertFalse(LogFilter.errors.matches(.info))
        XCTAssertTrue(LogFilter.warnings.matches(.warning))
        XCTAssertTrue(LogFilter.info.matches(.ok))
    }

    func testProtocolCoreRouting() {
        XCTAssertEqual(ProtocolKind.wireguard.core, .wireguard)
        XCTAssertEqual(ProtocolKind.reality.core, .xray)
        XCTAssertEqual(ProtocolKind.hysteria2.core, .singbox)
        XCTAssertEqual(ProtocolKind.ssh.core, .ssh)
    }

    func testRegistrySchemeRouting() {
        XCTAssertEqual(ProtocolRegistry.shared.kind(forScheme: "vless"), .vless)
        XCTAssertEqual(ProtocolRegistry.shared.kind(forScheme: "hy2"), .hysteria2)
        XCTAssertNil(ProtocolRegistry.shared.kind(forScheme: "wireguard"))
    }

    func testValidationRequiresName() {
        let empty = TunnelConfiguration(kind: .trojan)
        let issues = empty.validate()
        XCTAssertTrue(issues.hasErrors)
        // server, port and password are required for trojan.
        XCTAssertTrue(issues.contains { $0.fieldKey == FieldKey.password })
    }

    func testSSHRequiresPasswordOrKey() {
        var f = ConfigFields()
        f.set(FieldKey.name, "s"); f.set(FieldKey.server, "h"); f.set(FieldKey.port, 22); f.set(FieldKey.username, "root")
        f.set(FieldKey.tunnelMode, "Direct")
        let noAuth = TunnelConfiguration(kind: .ssh, fields: f)
        XCTAssertTrue(noAuth.validate().hasErrors)
        f.set(FieldKey.password, "pw")
        let withAuth = TunnelConfiguration(kind: .ssh, fields: f)
        XCTAssertFalse(withAuth.validate().hasErrors)
    }

    func testDuplicateGetsFreshIdentity() {
        let original = SampleData.configurations[0]
        let copy = original.duplicated(at: Date())
        XCTAssertNotEqual(original.id, copy.id)
        XCTAssertEqual(copy.name, original.name + " Copy")
        XCTAssertFalse(copy.metadata.isPinned)
    }
}
