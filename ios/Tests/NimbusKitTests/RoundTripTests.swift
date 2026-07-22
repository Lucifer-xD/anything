import XCTest
@testable import NimbusKit

/// Export a config to its share link, re-import it, and assert the essential
/// fields survive the trip. This is the strongest guarantee that parser and
/// serializer agree.
final class RoundTripTests: XCTestCase {
    let registry = ProtocolRegistry.shared
    let exporter = ConfigExporter()

    private func roundTrip(_ config: TunnelConfiguration, file: StaticString = #filePath, line: UInt = #line) throws -> TunnelConfiguration {
        let link = try XCTUnwrap(exporter.shareLink(for: config), "no share link", file: file, line: line)
        let uri = try XCTUnwrap(ConfigURI(link), "export not a URI: \(link)", file: file, line: line)
        return try XCTUnwrap(registry.parse(uri), "re-parse failed for \(link)", file: file, line: line)
    }

    func testVLESSRoundTrip() throws {
        var f = ConfigFields()
        f.set(FieldKey.name, "Edge WS")
        f.set(FieldKey.server, "edge.io"); f.set(FieldKey.port, 8443)
        f.set(FieldKey.uuid, "uuid-123"); f.set(FieldKey.security, "tls")
        f.set(FieldKey.sni, "cdn.io"); f.set(FieldKey.network, "ws"); f.set(FieldKey.path, "/ws")
        let original = TunnelConfiguration(kind: .vless, fields: f)
        let back = try roundTrip(original)
        XCTAssertEqual(back.fields.string(FieldKey.uuid), "uuid-123")
        XCTAssertEqual(back.host, "edge.io")
        XCTAssertEqual(back.port, 8443)
        XCTAssertEqual(back.fields.string(FieldKey.network), "ws")
        XCTAssertEqual(back.fields.string(FieldKey.path), "/ws")
        XCTAssertEqual(back.fields.string(FieldKey.sni), "cdn.io")
    }

    func testTrojanRoundTrip() throws {
        var f = ConfigFields()
        f.set(FieldKey.name, "Corp"); f.set(FieldKey.server, "corp.dev"); f.set(FieldKey.port, 443)
        f.set(FieldKey.password, "p@ss"); f.set(FieldKey.sni, "corp.dev"); f.set(FieldKey.network, "grpc")
        let back = try roundTrip(TunnelConfiguration(kind: .trojan, fields: f))
        XCTAssertEqual(back.fields.string(FieldKey.password), "p@ss")
        XCTAssertEqual(back.fields.string(FieldKey.sni), "corp.dev")
        XCTAssertEqual(back.fields.string(FieldKey.network), "grpc")
    }

    func testShadowsocksRoundTrip() throws {
        var f = ConfigFields()
        f.set(FieldKey.name, "SS"); f.set(FieldKey.server, "sg.ss.io"); f.set(FieldKey.port, 8388)
        f.set(FieldKey.cipher, "aes-256-gcm"); f.set(FieldKey.password, "pw")
        let back = try roundTrip(TunnelConfiguration(kind: .shadowsocks, fields: f))
        XCTAssertEqual(back.fields.string(FieldKey.cipher), "aes-256-gcm")
        XCTAssertEqual(back.fields.string(FieldKey.password), "pw")
        XCTAssertEqual(back.port, 8388)
    }

    func testVMessRoundTrip() throws {
        var f = ConfigFields()
        f.set(FieldKey.name, "VM"); f.set(FieldKey.server, "v.io"); f.set(FieldKey.port, 443)
        f.set(FieldKey.uuid, "vm-uuid"); f.set(FieldKey.network, "ws"); f.set(FieldKey.security, "tls")
        let back = try roundTrip(TunnelConfiguration(kind: .vmess, fields: f))
        XCTAssertEqual(back.fields.string(FieldKey.uuid), "vm-uuid")
        XCTAssertEqual(back.fields.string(FieldKey.network), "ws")
        XCTAssertEqual(back.fields.string(FieldKey.security), "tls")
    }

    func testHysteria2RoundTrip() throws {
        var f = ConfigFields()
        f.set(FieldKey.name, "H2"); f.set(FieldKey.server, "h.gg"); f.set(FieldKey.port, 8443)
        f.set(FieldKey.auth, "tok"); f.set(FieldKey.sni, "h.gg"); f.set(FieldKey.obfs, "salamander")
        let back = try roundTrip(TunnelConfiguration(kind: .hysteria2, fields: f))
        XCTAssertEqual(back.fields.string(FieldKey.auth), "tok")
        XCTAssertEqual(back.fields.string(FieldKey.obfs), "salamander")
    }

    func testTUICRoundTrip() throws {
        var f = ConfigFields()
        f.set(FieldKey.name, "TU"); f.set(FieldKey.server, "t.net"); f.set(FieldKey.port, 443)
        f.set(FieldKey.uuid, "tu-uuid"); f.set(FieldKey.password, "tp"); f.set(FieldKey.congestionControl, "bbr")
        let back = try roundTrip(TunnelConfiguration(kind: .tuic, fields: f))
        XCTAssertEqual(back.fields.string(FieldKey.uuid), "tu-uuid")
        XCTAssertEqual(back.fields.string(FieldKey.password), "tp")
        XCTAssertEqual(back.fields.string(FieldKey.congestionControl), "bbr")
    }

    func testBundleRoundTrip() throws {
        let data = try exporter.bundle(configs: SampleData.configurations, folders: ConfigFolder.defaults)
        let decoded = try NimbusBundle.decode(from: data)
        XCTAssertEqual(decoded.configs.count, SampleData.configurations.count)
        XCTAssertEqual(decoded.configs.first?.name, SampleData.configurations.first?.name)
    }
}
