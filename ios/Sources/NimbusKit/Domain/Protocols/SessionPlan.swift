import Foundation

/// The resolved, engine-ready description of a tunnel session. A
/// ``ProtocolModule`` turns a stored ``TunnelConfiguration`` into a `SessionPlan`;
/// the tunnel controller hands it to the active ``TunnelEngine`` (simulated in
/// this build, a real Packet Tunnel core in production).
///
/// It is deliberately framework-free and `Codable` so it can cross the app ↔
/// extension boundary as the `providerConfiguration` payload.
public struct SessionPlan: Codable, Equatable, Sendable {
    public var configID: UUID
    public var displayName: String
    public var kind: ProtocolKind
    public var core: TransportCore
    public var host: String
    public var port: Int
    /// DNS resolvers to install inside the tunnel.
    public var dnsServers: [String]
    public var mtu: Int?
    /// Routes to send through the tunnel (default `["0.0.0.0/0", "::/0"]`).
    public var includedRoutes: [String]
    /// Routes to exclude (split tunnelling / bypass LAN).
    public var excludedRoutes: [String]
    /// Core-specific key/value parameters (uuid, sni, flow, obfs, …). These are
    /// exactly what the embedded core (Xray/sing-box/WireGuard/SSH) consumes.
    public var parameters: [String: String]

    public init(
        configID: UUID,
        displayName: String,
        kind: ProtocolKind,
        core: TransportCore,
        host: String,
        port: Int,
        dnsServers: [String] = ["1.1.1.1", "1.0.0.1"],
        mtu: Int? = nil,
        includedRoutes: [String] = ["0.0.0.0/0", "::/0"],
        excludedRoutes: [String] = [],
        parameters: [String: String] = [:]
    ) {
        self.configID = configID
        self.displayName = displayName
        self.kind = kind
        self.core = core
        self.host = host
        self.port = port
        self.dnsServers = dnsServers
        self.mtu = mtu
        self.includedRoutes = includedRoutes
        self.excludedRoutes = excludedRoutes
        self.parameters = parameters
    }
}
