import XCTest
@testable import NimbusKit

final class TunnelTests: XCTestCase {
    /// Build a controller wired to a fast simulated engine and a seeded store.
    private func makeController() async -> (TunnelController, DefaultConfigurationStore, StatisticsService, UUID) {
        let clock = MutableClock()
        let store = DefaultConfigurationStore(clock: clock, seed: SampleData.snapshot)
        let logs = LogStore()
        let stats = StatisticsService(clock: clock)
        let engine = SimulatedTunnelEngine(clock: clock, tickNanos: 1_000_000) // 1ms ticks
        let controller = TunnelController(engine: engine, store: store, logStore: logs, statistics: stats, clock: clock)
        let id = await store.allConfigurations().first!.id
        return (controller, store, stats, id)
    }

    func testConnectReachesConnected() async throws {
        let (controller, _, _, id) = await makeController()
        try await controller.connect(configID: id)
        let connected = await eventually { await controller.state == .connected }
        XCTAssertTrue(connected, "tunnel never reached .connected")
        let active = await controller.activeConfigID
        XCTAssertEqual(active, id)
    }

    func testDisconnectReturnsToIdleAndRecordsSession() async throws {
        let (controller, _, stats, id) = await makeController()
        try await controller.connect(configID: id)
        _ = await eventually { await controller.state == .connected }
        await controller.disconnect()
        let disconnected = await eventually { await controller.state == .disconnected }
        XCTAssertTrue(disconnected, "tunnel never returned to .disconnected")
        // finalizeSession runs asynchronously once the event stream ends; poll for it.
        let recorded = await eventually { await stats.allSessions().count == 1 }
        XCTAssertTrue(recorded, "session was not recorded")
        let sessions = await stats.allSessions()
        XCTAssertNotNil(sessions.first?.endedAt)
    }

    func testConnectValidatesConfiguration() async throws {
        let clock = MutableClock()
        let store = DefaultConfigurationStore(clock: clock)
        // An invalid trojan config (missing password/server).
        let invalid = TunnelConfiguration(kind: .trojan)
        try await store.save(invalid)
        let controller = TunnelController(
            engine: SimulatedTunnelEngine(clock: clock, tickNanos: 1_000_000),
            store: store, logStore: LogStore(), statistics: StatisticsService(clock: clock), clock: clock
        )
        do {
            try await controller.connect(configID: invalid.id)
            XCTFail("expected validation error")
        } catch let error as NimbusError {
            if case .validation = error { /* ok */ } else { XCTFail("wrong error: \(error)") }
        }
    }

    func testProbeLatency() async {
        let engine = SimulatedTunnelEngine(tickNanos: 1_000_000)
        let latency = await engine.probeLatency(host: "de1.nimbus.net", port: 443)
        XCTAssertNotNil(latency)
        XCTAssertGreaterThan(latency ?? 0, 0)
    }

    func testServerRegistryRefreshesLatency() async {
        let engine = SimulatedTunnelEngine(tickNanos: 1_000_000)
        let registry = ServerRegistry(servers: SampleData.servers, probe: EngineLatencyProbe(engine: engine))
        await registry.refreshLatencies()
        let list = await registry.list(sort: .latency)
        XCTAssertTrue(list.allSatisfy { $0.latencyMillis != nil })
        // Sorted ascending by latency.
        let latencies = list.compactMap { $0.latencyMillis }
        XCTAssertEqual(latencies, latencies.sorted())
    }
}
