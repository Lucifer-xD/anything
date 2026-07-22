import Foundation

/// An offline subscription fetcher that returns a small, deterministic set of
/// nodes as a base64 blob. Lets "Update All" work in the simulated build and in
/// tests. The app replaces it with a `URLSession`-backed fetcher.
public struct StubSubscriptionFetcher: SubscriptionFetching {
    public init() {}

    public func fetch(_ url: URL) async throws -> (body: String, userInfo: SubscriptionUserInfo?) {
        let links = [
            "vless://d3adb33f-1234-5678-9abc-def012345678@de1.nimbus.net:443?type=tcp&security=reality&sni=www.apple.com&fp=chrome&pbk=demoPublicKey&sid=0123abcd&flow=xtls-rprx-vision#DE · Reality 443",
            "hysteria2://s3cr3t@nl.hy2.net:8443?sni=example.com&obfs=salamander#NL · Hysteria2",
            "ss://YWVzLTI1Ni1nY206c3MtcGFzc3dvcmQ@sg.ss.io:8388#SG · Shadowsocks",
        ]
        let blob = Data(links.joined(separator: "\n").utf8).base64EncodedString()
        let info = SubscriptionUserInfo(
            uploadBytes: 3 * 1_073_741_824,
            downloadBytes: 79 * 1_073_741_824,
            totalBytes: 500 * 1_073_741_824,
            expiresAt: Date(timeIntervalSince1970: 1_752_000_000).addingTimeInterval(46 * 86_400)
        )
        return (blob, info)
    }
}
