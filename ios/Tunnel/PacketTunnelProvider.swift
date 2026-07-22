import Foundation
import NimbusKit
#if canImport(NetworkExtension)
import NetworkExtension
#endif
#if canImport(WireGuardKit)
import WireGuardKit
#endif

/// The `NEPacketTunnelProvider` that runs in the tunnel extension process.
///
/// It reads the ``SessionPlan`` the app passed through the provider configuration
/// and starts the matching core:
///   • `.wireguard` → the **real** WireGuardKit adapter (wireguard-go), which
///     applies its own network settings and carries packets.
///   • anything else → the ``ReferenceTunnelBridge`` placeholder until that core
///     (sing-box / Xray / …) is wired in.
///
/// The extension runs under a hard ~50 MB budget — see `docs/RESEARCH.md §3.8`.
final class PacketTunnelProvider: NEPacketTunnelProvider {
    private let decoder = JSONDecoder()
    private var activeCore: TransportCore?
    private let fallbackBridge = ReferenceTunnelBridge()

    #if canImport(WireGuardKit)
    private lazy var wgAdapter: WireGuardAdapter = {
        WireGuardAdapter(with: self) { _, message in
            NSLog("[NimbusWG] %@", message)
        }
    }()
    #endif

    // MARK: - Lifecycle

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        guard let plan = loadPlan() else {
            completionHandler(NimbusError.tunnel(reason: "missing or invalid session plan"))
            return
        }
        activeCore = plan.core

        #if canImport(WireGuardKit)
        if plan.core == .wireguard {
            startWireGuard(plan: plan, completionHandler: completionHandler)
            return
        }
        #endif

        // Fallback path for cores not yet wired to a real engine.
        Task {
            do {
                let settings = try await fallbackBridge.start(
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
        #if canImport(WireGuardKit)
        if activeCore == .wireguard {
            wgAdapter.stop { _ in completionHandler() }
            return
        }
        #endif
        Task {
            await fallbackBridge.stop()
            completionHandler()
        }
    }

    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        completionHandler?(messageData)
    }

    // MARK: - WireGuard

    #if canImport(WireGuardKit)
    private func startWireGuard(plan: SessionPlan, completionHandler: @escaping (Error?) -> Void) {
        let wgQuick = Self.wgQuickConfig(from: plan)
        do {
            // Qualify to avoid the name clash with NimbusKit.TunnelConfiguration.
            let configuration = try WireGuardKit.TunnelConfiguration(fromWgQuickConfig: wgQuick, called: plan.displayName)
            wgAdapter.start(tunnelConfiguration: configuration) { adapterError in
                if let adapterError {
                    completionHandler(NimbusError.tunnel(reason: "WireGuard start failed: \(adapterError)"))
                } else {
                    NSLog("[NimbusWG] tunnel up for %@", plan.displayName)
                    completionHandler(nil)
                }
            }
        } catch {
            completionHandler(NimbusError.tunnel(reason: "invalid WireGuard configuration: \(error)"))
        }
    }
    #endif

    /// Rebuild a `wg-quick` INI from the resolved plan parameters (produced by
    /// ``WireGuardModule/makeSessionPlan(_:)``). WireGuardKit parses this form.
    static func wgQuickConfig(from plan: SessionPlan) -> String {
        let p = plan.parameters
        var lines: [String] = ["[Interface]"]
        if let key = p["private_key"], !key.isEmpty { lines.append("PrivateKey = \(key)") }
        if let address = p["address"], !address.isEmpty { lines.append("Address = \(address)") }
        if !plan.dnsServers.isEmpty { lines.append("DNS = \(plan.dnsServers.joined(separator: ", "))") }
        if let mtu = plan.mtu { lines.append("MTU = \(mtu)") }

        lines.append("")
        lines.append("[Peer]")
        if let pub = p["public_key"], !pub.isEmpty { lines.append("PublicKey = \(pub)") }
        if let psk = p["preshared_key"], !psk.isEmpty { lines.append("PresharedKey = \(psk)") }
        lines.append("Endpoint = \(plan.host):\(plan.port)")
        let allowed = plan.includedRoutes.isEmpty ? ["0.0.0.0/0", "::/0"] : plan.includedRoutes
        lines.append("AllowedIPs = \(allowed.joined(separator: ", "))")
        if let keepalive = p["keepalive"], let value = Int(keepalive), value > 0 {
            lines.append("PersistentKeepalive = \(value)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Plan + fallback settings

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
        dns.matchDomains = [""]
        ne.dnsSettings = dns
        ne.mtu = NSNumber(value: settings.mtu)
        try await setTunnelNetworkSettings(ne)
    }

    private static func ipv4Route(_ cidr: String) -> NEIPv4Route? {
        if cidr == "0.0.0.0/0" { return NEIPv4Route.default() }
        let parts = cidr.split(separator: "/")
        guard parts.count == 2, let prefix = Int(parts[1]) else { return nil }
        return NEIPv4Route(destinationAddress: String(parts[0]), subnetMask: mask(fromPrefix: prefix))
    }

    private static func mask(fromPrefix prefix: Int) -> String {
        let clamped = max(0, min(32, prefix))
        var bits = UInt32(0)
        if clamped > 0 { bits = ~UInt32(0) << (32 - clamped) }
        return "\((bits >> 24) & 0xFF).\((bits >> 16) & 0xFF).\((bits >> 8) & 0xFF).\(bits & 0xFF)"
    }
}
