import Foundation
import NimbusKit

/// The boundary where a **real** protocol core plugs into the Packet Tunnel
/// extension. Everything above this in NimbusKit (parsing, planning, the
/// controller, statistics, logging) is real and tested; a `TunnelBridge` is the
/// last mile that actually moves bytes.
///
/// A concrete bridge takes the `SessionPlan` (already resolved from the user's
/// configuration by the owning ``ProtocolModule``) plus the extension's packet
/// flow, and runs the chosen core. Which core depends on `plan.core`:
///
/// | `plan.core` | Recommended embed                                   |
/// |-------------|-----------------------------------------------------|
/// | `.wireguard`| WireGuardKit (`wg-apple`) — set from the WG params  |
/// | `.xray`     | Xray-core via `libXray`/gomobile (VLESS/VMess/…)    |
/// | `.singbox`  | sing-box `libbox` (Hysteria2 / TUIC / universal)   |
/// | `.ssh`      | an SSH client + `tun2socks` for the payload modes   |
/// | `.openvpn`  | OpenVPNAdapter                                       |
/// | `.tls`/`.proxy`/`.dns` | `tun2socks` over the wrapped transport  |
///
/// See `docs/RESEARCH.md §3` (iOS tunnel architecture) for the full integration
/// notes, entitlements and the memory-budget constraints.
public protocol TunnelBridge: AnyObject {
    /// Start carrying traffic for `plan`. Report readiness via `onState` and
    /// throughput via `onTraffic`. Must return the network settings the provider
    /// should apply (addresses, DNS, routes, MTU).
    func start(
        plan: SessionPlan,
        onState: @escaping (ConnectionState) -> Void,
        onTraffic: @escaping (TrafficSample) -> Void,
        onLog: @escaping (LogEntry) -> Void
    ) async throws -> TunnelNetworkSettings

    /// Stop the core and flush.
    func stop() async
}

/// Framework-free description of the tunnel's network settings, mapped by the
/// provider onto `NEPacketTunnelNetworkSettings`.
public struct TunnelNetworkSettings: Sendable {
    public var tunnelRemoteAddress: String
    public var ipv4Addresses: [String]
    public var ipv4SubnetMasks: [String]
    public var ipv6Addresses: [String]
    public var ipv6PrefixLengths: [NSNumber]
    public var dnsServers: [String]
    public var includedRoutesCIDR: [String]
    public var excludedRoutesCIDR: [String]
    public var mtu: Int

    public init(
        tunnelRemoteAddress: String,
        ipv4Addresses: [String] = ["10.66.0.2"],
        ipv4SubnetMasks: [String] = ["255.255.255.255"],
        ipv6Addresses: [String] = [],
        ipv6PrefixLengths: [NSNumber] = [],
        dnsServers: [String] = ["1.1.1.1", "1.0.0.1"],
        includedRoutesCIDR: [String] = ["0.0.0.0/0", "::/0"],
        excludedRoutesCIDR: [String] = [],
        mtu: Int = 1420
    ) {
        self.tunnelRemoteAddress = tunnelRemoteAddress
        self.ipv4Addresses = ipv4Addresses
        self.ipv4SubnetMasks = ipv4SubnetMasks
        self.ipv6Addresses = ipv6Addresses
        self.ipv6PrefixLengths = ipv6PrefixLengths
        self.dnsServers = dnsServers
        self.includedRoutesCIDR = includedRoutesCIDR
        self.excludedRoutesCIDR = excludedRoutesCIDR
        self.mtu = mtu
    }

    /// Derive sensible settings from a plan.
    public static func from(_ plan: SessionPlan) -> TunnelNetworkSettings {
        TunnelNetworkSettings(
            tunnelRemoteAddress: plan.host,
            dnsServers: plan.dnsServers,
            includedRoutesCIDR: plan.includedRoutes,
            excludedRoutesCIDR: plan.excludedRoutes,
            mtu: plan.mtu ?? 1420
        )
    }
}

/// A reference bridge that stands in for a real core: it applies plausible
/// network settings and reports a healthy session so the full app→extension
/// path (permission, provider start, settings, status) can be exercised on a
/// device. Replace with a `WireGuardBridge` / `SingBoxBridge` / `XrayBridge`
/// conforming to ``TunnelBridge`` to ship real tunnelling.
public final class ReferenceTunnelBridge: TunnelBridge {
    private var task: Task<Void, Never>?

    public init() {}

    public func start(
        plan: SessionPlan,
        onState: @escaping (ConnectionState) -> Void,
        onTraffic: @escaping (TrafficSample) -> Void,
        onLog: @escaping (LogEntry) -> Void
    ) async throws -> TunnelNetworkSettings {
        onLog(LogEntry(level: .info, category: "bridge", message: "Bridge starting core=\(plan.core.rawValue)"))
        onState(.connecting)
        // A real bridge would hand the packet flow to the core here.
        onState(.connected)
        onLog(LogEntry(level: .ok, category: "bridge", message: "Core up — routing via tunnel"))
        return TunnelNetworkSettings.from(plan)
    }

    public func stop() async {
        task?.cancel()
        task = nil
    }
}
