import Foundation
import NimbusKit
#if canImport(NetworkExtension)
import NetworkExtension

/// The `NEPacketTunnelProvider` that runs in the tunnel extension process. It:
///
/// 1. reads the ``SessionPlan`` handed over by the app through the provider
///    configuration (`NETunnelProviderProtocol.providerConfiguration`),
/// 2. hands it to a ``TunnelBridge`` (the real core plugs in here),
/// 3. applies the returned network settings to the utun interface, and
/// 4. relays state/traffic/logs back for the app to display.
///
/// The extension runs under a hard ~50 MB memory budget — see `docs/RESEARCH.md
/// §3.8`. Keep buffers small and prefer a Go/Rust core over a Swift TCP stack.
final class PacketTunnelProvider: NEPacketTunnelProvider {
    private let bridge: TunnelBridge = ReferenceTunnelBridge()
    private let decoder = JSONDecoder()

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        guard let plan = loadPlan() else {
            completionHandler(NimbusError.tunnel(reason: "missing or invalid session plan"))
            return
        }
        Task {
            do {
                let settings = try await bridge.start(
                    plan: plan,
                    onState: { _ in },
                    onTraffic: { _ in },
                    onLog: { entry in NSLog("[Nimbus] %@", entry.plainText) }
                )
                try await applySettings(settings)
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        Task {
            await bridge.stop()
            completionHandler()
        }
    }

    /// App ↔ extension IPC channel (e.g. live stats requests).
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        completionHandler?(messageData)
    }

    // MARK: - Helpers

    private func loadPlan() -> SessionPlan? {
        guard
            let proto = protocolConfiguration as? NETunnelProviderProtocol,
            let config = proto.providerConfiguration,
            let data = config["plan"] as? Data
        else { return nil }
        return try? decoder.decode(SessionPlan.self, from: data)
    }

    private func applySettings(_ settings: TunnelNetworkSettings) async throws {
        let ne = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: settings.tunnelRemoteAddress)

        let ipv4 = NEIPv4Settings(addresses: settings.ipv4Addresses, subnetMasks: settings.ipv4SubnetMasks)
        ipv4.includedRoutes = settings.includedRoutesCIDR.compactMap(Self.ipv4Route)
        ipv4.excludedRoutes = settings.excludedRoutesCIDR.compactMap(Self.ipv4Route)
        ne.ipv4Settings = ipv4

        if !settings.ipv6Addresses.isEmpty {
            ne.ipv6Settings = NEIPv6Settings(addresses: settings.ipv6Addresses, networkPrefixLengths: settings.ipv6PrefixLengths)
        }

        let dns = NEDNSSettings(servers: settings.dnsServers)
        dns.matchDomains = [""] // route all DNS through the tunnel (leak prevention)
        ne.dnsSettings = dns
        ne.mtu = NSNumber(value: settings.mtu)

        try await setTunnelNetworkSettings(ne)
    }

    private static func ipv4Route(_ cidr: String) -> NEIPv4Route? {
        if cidr == "0.0.0.0/0" { return NEIPv4Route.default() }
        let parts = cidr.split(separator: "/")
        guard parts.count == 2, let prefix = Int(parts[1]) else { return nil }
        let mask = Self.mask(fromPrefix: prefix)
        return NEIPv4Route(destinationAddress: String(parts[0]), subnetMask: mask)
    }

    private static func mask(fromPrefix prefix: Int) -> String {
        let clamped = max(0, min(32, prefix))
        var bits = UInt32(0)
        if clamped > 0 { bits = ~UInt32(0) << (32 - clamped) }
        return "\((bits >> 24) & 0xFF).\((bits >> 16) & 0xFF).\((bits >> 8) & 0xFF).\(bits & 0xFF)"
    }
}
#endif
