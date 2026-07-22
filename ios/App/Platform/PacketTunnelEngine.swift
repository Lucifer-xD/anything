import Foundation
import NimbusKit
#if canImport(NetworkExtension)
import NetworkExtension
#endif
#if canImport(Network)
import Network
#endif

/// Production ``TunnelEngine`` that drives the system VPN via
/// `NETunnelProviderManager`. It installs/updates the tunnel configuration,
/// encodes the ``SessionPlan`` into the provider configuration, starts the
/// extension, and maps `NEVPNStatus` changes to ``TunnelEvent``s.
///
/// Swap it in for `SimulatedTunnelEngine` in `NimbusVPNApp` once the extension
/// ships with a real ``TunnelBridge`` and provisioning is in place.
final class PacketTunnelEngine: NSObject, TunnelEngine, @unchecked Sendable {
    private let providerBundleID: String
    private var continuation: AsyncStream<TunnelEvent>.Continuation?
    #if canImport(NetworkExtension)
    private var manager: NETunnelProviderManager?
    private var statusObserver: NSObjectProtocol?
    #endif

    init(providerBundleID: String = "net.nimbus.vpn.tunnel") {
        self.providerBundleID = providerBundleID
    }

    func start(_ plan: SessionPlan) async -> AsyncStream<TunnelEvent> {
        let (stream, continuation) = AsyncStream<TunnelEvent>.makeStream()
        self.continuation = continuation
        #if canImport(NetworkExtension)
        do {
            let manager = try await loadOrCreateManager()
            self.manager = manager
            try configure(manager, with: plan)
            try await manager.saveToPreferences()
            try await manager.loadFromPreferences()
            observeStatus(manager)
            continuation.yield(.log(LogEntry(level: .info, message: "Starting tunnel \(plan.displayName)")))
            try manager.connection.startVPNTunnel()
        } catch {
            continuation.yield(.state(.failed(reason: error.localizedDescription)))
            continuation.finish()
        }
        #else
        continuation.yield(.state(.failed(reason: "NetworkExtension unavailable")))
        continuation.finish()
        #endif
        return stream
    }

    func stop() async {
        #if canImport(NetworkExtension)
        manager?.connection.stopVPNTunnel()
        #endif
    }

    func probeLatency(host: String, port: Int) async -> Int? {
        #if canImport(Network)
        return await withCheckedContinuation { continuation in
            let start = DispatchTime.now()
            let endpoint = NWEndpoint.hostPort(host: .init(host), port: .init(rawValue: UInt16(port)) ?? 443)
            let connection = NWConnection(to: endpoint, using: .tcp)
            var resumed = false
            func finish(_ value: Int?) {
                guard !resumed else { return }
                resumed = true
                connection.cancel()
                continuation.resume(returning: value)
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    let ms = Int(Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000)
                    finish(ms)
                case .failed, .cancelled:
                    finish(nil)
                default: break
                }
            }
            connection.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + 3) { finish(nil) }
        }
        #else
        return nil
        #endif
    }

    #if canImport(NetworkExtension)
    private func loadOrCreateManager() async throws -> NETunnelProviderManager {
        let managers = try await NETunnelProviderManager.loadAllFromPreferences()
        return managers.first ?? NETunnelProviderManager()
    }

    private func configure(_ manager: NETunnelProviderManager, with plan: SessionPlan) throws {
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = providerBundleID
        proto.serverAddress = "\(plan.host):\(plan.port)"
        let data = try JSONEncoder().encode(plan)
        proto.providerConfiguration = ["plan": data]
        manager.protocolConfiguration = proto
        manager.localizedDescription = "Nimbus — \(plan.displayName)"
        manager.isEnabled = true
    }

    private func observeStatus(_ manager: NETunnelProviderManager) {
        statusObserver = NotificationCenter.default.addObserver(
            forName: .NEVPNStatusDidChange,
            object: manager.connection,
            queue: .main
        ) { [weak self] _ in
            self?.emitStatus(manager.connection.status)
        }
    }

    private func emitStatus(_ status: NEVPNStatus) {
        let state: ConnectionState
        switch status {
        case .connecting: state = .connecting
        case .connected: state = .connected
        case .reasserting: state = .reasserting
        case .disconnecting: state = .disconnecting
        case .disconnected, .invalid: state = .disconnected
        @unknown default: state = .disconnected
        }
        continuation?.yield(.state(state))
        if status == .disconnected {
            if let statusObserver { NotificationCenter.default.removeObserver(statusObserver) }
            continuation?.finish()
        }
    }
    #endif
}
