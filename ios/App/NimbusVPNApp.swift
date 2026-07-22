import SwiftUI
import NimbusKit

@main
struct NimbusVPNApp: App {
    @StateObject private var model: AppModel

    init() {
        // Compose the production service graph. Persistence lives in the shared
        // app-group container so the Packet Tunnel extension can read it too.
        let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: "group.net.nimbus.vpn")
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let configuration = AppEnvironmentConfiguration(
            storageDirectory: container.appendingPathComponent("Nimbus", isDirectory: true),
            seedSampleData: true,
            engine: makeTunnelEngine(),                 // real Packet Tunnel engine in the full build
            subscriptionFetcher: URLSessionSubscriptionFetcher(),
            appLockAuthenticator: BiometricAuthenticator(),
            syncCipher: makeSyncCipher(),
            secureStore: KeychainSecureStore()
        )
        _model = StateObject(wrappedValue: AppModel(services: AppServices(configuration: configuration)))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .nimbusPalette(model.palette)
                .task { await model.start() }
        }
    }
}

/// Selects the strongest available E2E cipher for sync.
private func makeSyncCipher() -> ConfigurationCipher {
    #if canImport(CryptoKit)
    return AESGCMCipher()
    #else
    return PassthroughCipher()
    #endif
}

/// The full (paid) build defines `NIMBUS_REAL_TUNNEL` and drives the system VPN
/// through the Packet Tunnel extension; the free / no-extension build uses the
/// in-process simulated engine.
private func makeTunnelEngine() -> TunnelEngine {
    #if NIMBUS_REAL_TUNNEL
    return PacketTunnelEngine()
    #else
    return SimulatedTunnelEngine()
    #endif
}
