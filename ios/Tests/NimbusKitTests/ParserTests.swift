import XCTest
@testable import NimbusKit

final class ParserTests: XCTestCase {
    let registry = ProtocolRegistry.shared

    private func parse(_ link: String) throws -> TunnelConfiguration {
        let uri = try XCTUnwrap(ConfigURI(link), "not a URI: \(link)")
        return try XCTUnwrap(registry.parse(uri), "no module parsed \(link)")
    }

    // MARK: VLESS + Reality

    func testVLESSRealityLink() throws {
        let link = "vless://d3adb33f-1234-5678-9abc-def012345678@de1.nimbus.net:443?type=tcp&security=reality&sni=www.apple.com&fp=chrome&pbk=PUBKEY&sid=0123abcd&flow=xtls-rprx-vision#DE%20Reality"
        let config = try parse(link)
        XCTAssertEqual(config.kind, .reality, "reality security must promote kind to .reality")
        XCTAssertEqual(config.name, "DE Reality")
        XCTAssertEqual(config.host, "de1.nimbus.net")
        XCTAssertEqual(config.port, 443)
        XCTAssertEqual(config.fields.string(FieldKey.uuid), "d3adb33f-1234-5678-9abc-def012345678")
        XCTAssertEqual(config.fields.string(FieldKey.sni), "www.apple.com")
        XCTAssertEqual(config.fields.string(FieldKey.realityPublicKey), "PUBKEY")
        XCTAssertEqual(config.fields.string(FieldKey.shortID), "0123abcd")
        XCTAssertEqual(config.fields.string(FieldKey.flow), "xtls-rprx-vision")
        XCTAssertEqual(config.fields.string(FieldKey.network), "tcp")
    }

    func testVLESSPlainStaysVLESS() throws {
        let config = try parse("vless://uuid-1@edge.io:8443?type=ws&security=tls&sni=cdn.io&path=/v#Edge")
        XCTAssertEqual(config.kind, .vless)
        XCTAssertEqual(config.fields.string(FieldKey.network), "ws")
        XCTAssertEqual(config.fields.string(FieldKey.path), "/v")
    }

    // MARK: VMess

    func testVMessBase64JSON() throws {
        let json = """
        {"v":"2","ps":"US Node","add":"us.v2.cloud","port":"443","id":"abcd-uuid","aid":"0","net":"ws","path":"/ray","host":"cdn.example.com","tls":"tls","sni":"cdn.example.com","scy":"auto"}
        """
        let link = "vmess://" + Data(json.utf8).base64EncodedString()
        let config = try parse(link)
        XCTAssertEqual(config.kind, .vmess)
        XCTAssertEqual(config.name, "US Node")
        XCTAssertEqual(config.host, "us.v2.cloud")
        XCTAssertEqual(config.port, 443)
        XCTAssertEqual(config.fields.string(FieldKey.uuid), "abcd-uuid")
        XCTAssertEqual(config.fields.string(FieldKey.network), "ws")
        XCTAssertEqual(config.fields.string(FieldKey.path), "/ray")
        XCTAssertEqual(config.fields.string(FieldKey.security), "tls")
    }

    // MARK: Trojan

    func testTrojanLink() throws {
        let config = try parse("trojan://secretpw@edge.corp.dev:443?sni=corp.dev&type=ws&path=/t&allowInsecure=1#Work")
        XCTAssertEqual(config.kind, .trojan)
        XCTAssertEqual(config.fields.string(FieldKey.password), "secretpw")
        XCTAssertEqual(config.fields.string(FieldKey.sni), "corp.dev")
        XCTAssertEqual(config.fields.string(FieldKey.network), "ws")
        XCTAssertTrue(config.fields.bool(FieldKey.allowInsecure))
    }

    // MARK: Shadowsocks — SIP002 and legacy

    func testShadowsocksSIP002() throws {
        let userinfo = "aes-256-gcm:sspass".base64URLEncoded()
        let config = try parse("ss://\(userinfo)@sg.ss.stream:8388#SG")
        XCTAssertEqual(config.kind, .shadowsocks)
        XCTAssertEqual(config.fields.string(FieldKey.cipher), "aes-256-gcm")
        XCTAssertEqual(config.fields.string(FieldKey.password), "sspass")
        XCTAssertEqual(config.host, "sg.ss.stream")
        XCTAssertEqual(config.port, 8388)
    }

    func testShadowsocksLegacy() throws {
        let inner = "chacha20-ietf-poly1305:pw@host.ss.io:8443"
        let link = "ss://" + Data(inner.utf8).base64EncodedString() + "#Legacy"
        let config = try parse(link)
        XCTAssertEqual(config.fields.string(FieldKey.cipher), "chacha20-ietf-poly1305")
        XCTAssertEqual(config.fields.string(FieldKey.password), "pw")
        XCTAssertEqual(config.host, "host.ss.io")
        XCTAssertEqual(config.port, 8443)
    }

    // MARK: Hysteria2 / TUIC

    func testHysteria2Link() throws {
        let config = try parse("hysteria2://token123@jp.hy2.gg:8443?sni=example.com&obfs=salamander&obfs-password=op&insecure=1#Tokyo")
        XCTAssertEqual(config.kind, .hysteria2)
        XCTAssertEqual(config.fields.string(FieldKey.auth), "token123")
        XCTAssertEqual(config.fields.string(FieldKey.obfs), "salamander")
        XCTAssertEqual(config.fields.string(FieldKey.obfsPassword), "op")
        XCTAssertTrue(config.fields.bool(FieldKey.allowInsecure))
    }

    func testHy2AliasScheme() throws {
        let config = try parse("hy2://token@host.gg:443#Alias")
        XCTAssertEqual(config.kind, .hysteria2)
        XCTAssertEqual(config.fields.string(FieldKey.auth), "token")
    }

    func testTUICLink() throws {
        let config = try parse("tuic://uuid-x:passy@tuic.example.net:443?sni=example.net&congestion_control=bbr&udp_relay_mode=native&alpn=h3#TU")
        XCTAssertEqual(config.kind, .tuic)
        XCTAssertEqual(config.fields.string(FieldKey.uuid), "uuid-x")
        XCTAssertEqual(config.fields.string(FieldKey.password), "passy")
        XCTAssertEqual(config.fields.string(FieldKey.congestionControl), "bbr")
        XCTAssertEqual(config.fields.string(FieldKey.udpRelayMode), "native")
    }

    // MARK: WireGuard .conf

    func testWireGuardConf() throws {
        let conf = """
        # Name = Amsterdam
        [Interface]
        PrivateKey = aPrivateKeyBase64=
        Address = 10.66.0.2/32, fd00::2/128
        DNS = 1.1.1.1
        MTU = 1420

        [Peer]
        PublicKey = aPublicKeyBase64=
        Endpoint = nl.wg.example.io:51820
        AllowedIPs = 0.0.0.0/0, ::/0
        PersistentKeepalive = 25
        """
        let config = try WireGuardConfParser.parse(conf)
        XCTAssertEqual(config.kind, .wireguard)
        XCTAssertEqual(config.name, "Amsterdam")
        XCTAssertEqual(config.fields.string(FieldKey.interfacePrivateKey), "aPrivateKeyBase64=")
        XCTAssertEqual(config.fields.string(FieldKey.endpoint), "nl.wg.example.io:51820")
        XCTAssertEqual(config.host, "nl.wg.example.io")
        XCTAssertEqual(config.port, 51820)
        XCTAssertEqual(config.fields.int(FieldKey.keepAlive), 25)
    }

    // MARK: Importer detection

    func testImporterSingleLink() {
        let result = ConfigImporter().import("trojan://pw@h.dev:443#X")
        XCTAssertEqual(result.configs.count, 1)
        XCTAssertTrue(result.failures.isEmpty)
    }

    func testImporterBase64Subscription() {
        let links = "vless://u@a.io:443?security=tls&sni=a\ntrojan://pw@b.io:443#B"
        let blob = Data(links.utf8).base64EncodedString()
        let result = ConfigImporter().import(blob)
        XCTAssertEqual(result.configs.count, 2)
        XCTAssertEqual(result.detectedSource, .subscription)
    }

    func testImporterWireGuardDetected() {
        let conf = "[Interface]\nPrivateKey = k=\n[Peer]\nPublicKey = p=\nEndpoint = h:51820\n"
        let result = ConfigImporter().import(conf)
        XCTAssertEqual(result.configs.first?.kind, .wireguard)
    }

    func testImporterReportsFailures() {
        let result = ConfigImporter().import("not-a-link\nvmess://%%%bad")
        XCTAssertTrue(result.isEmpty)
        XCTAssertFalse(result.failures.isEmpty)
    }
}
