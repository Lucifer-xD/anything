import Foundation

/// The connection lifecycle owner. It resolves a configuration into a
/// ``SessionPlan``, drives the active ``TunnelEngine``, and fans engine events
/// out to the app while keeping the store, statistics and logs in sync:
///
/// connect → validate → plan → engine.start → (state / traffic / log events) →
/// disconnect → finalize session.
///
/// The whole flow is real; only the packet-carrying ``TunnelEngine`` is
/// simulated in this build.
public actor TunnelController {
    public private(set) var state: ConnectionState = .disconnected
    public private(set) var activeConfigID: UUID?
    public private(set) var lastSample: TrafficSample?
    public private(set) var sessionStart: Date?

    private let engine: TunnelEngine
    private let store: ConfigurationStore
    private let logStore: LogStore
    private let statistics: StatisticsService
    private let registry: ProtocolRegistry
    private let clock: DateProviding
    private let broadcaster = AsyncBroadcaster<TunnelEvent>()
    private var pump: Task<Void, Never>?

    public init(
        engine: TunnelEngine,
        store: ConfigurationStore,
        logStore: LogStore,
        statistics: StatisticsService,
        registry: ProtocolRegistry = .shared,
        clock: DateProviding = SystemClock()
    ) {
        self.engine = engine
        self.store = store
        self.logStore = logStore
        self.statistics = statistics
        self.registry = registry
        self.clock = clock
    }

    /// A live stream of every tunnel event (state, traffic, logs) for view models.
    public func events() async -> AsyncStream<TunnelEvent> {
        await broadcaster.stream()
    }

    /// Seconds the current session has been up (0 when idle).
    public func elapsedSeconds(now: Date) -> Int {
        guard let sessionStart, state.isActive else { return 0 }
        return max(0, Int(now.timeIntervalSince(sessionStart)))
    }

    // MARK: - Control

    public func connect(configID: UUID) async throws {
        guard let config = await store.configuration(id: configID) else {
            throw NimbusError.notFound(id: configID.uuidString)
        }
        let module = registry.module(for: config.kind)
        let issues = module.validate(config)
        if issues.hasErrors { throw NimbusError.validation(issues) }

        let plan = try module.makeSessionPlan(config)
        activeConfigID = configID
        sessionStart = clock.now()
        state = .connecting
        await statistics.beginSession(config: config)
        await store.recordConnection(configID, at: clock.now())

        let stream = await engine.start(plan)
        pump?.cancel()
        pump = Task { [weak self] in await self?.pump(stream, configID: configID) }
    }

    /// Connect to the most-recently-active config, or the first available one.
    public func quickConnect() async throws {
        if let id = activeConfigID {
            try await connect(configID: id)
        } else if let first = await store.allConfigurations().first {
            try await connect(configID: first.id)
        } else {
            throw NimbusError.notFound(id: "no configurations")
        }
    }

    public func disconnect() async {
        guard state.isActive || state.isBusy else { return }
        await engine.stop()
        // Engine emits disconnecting/disconnected then finishes the stream; the
        // pump loop finalizes the session when the stream ends.
    }

    /// Toggle helper for the dashboard's single connect/disconnect button.
    public func toggle(configID: UUID) async throws {
        if state.isActive, activeConfigID == configID {
            await disconnect()
        } else {
            try await connect(configID: configID)
        }
    }

    // MARK: - Event pump

    private func pump(_ stream: AsyncStream<TunnelEvent>, configID: UUID) async {
        for await event in stream {
            switch event {
            case let .state(newState):
                state = newState
                if case let .failed(reason) = newState {
                    await statistics.endSession(failureReason: reason)
                }
            case let .traffic(sample):
                lastSample = sample
                await statistics.updateOpenSession(
                    rxBytes: sample.rxBytes,
                    txBytes: sample.txBytes,
                    latencyMillis: nil
                )
            case let .log(entry):
                await logStore.append(entry)
            }
            await broadcaster.emit(event)
        }
        await finalizeSession(configID: configID)
    }

    private func finalizeSession(configID: UUID) async {
        if let sample = lastSample {
            await store.addTraffic(configID, bytes: sample.rxBytes &+ sample.txBytes)
        }
        await statistics.endSession()
        if state.isActive || state.isBusy { state = .disconnected }
        sessionStart = nil
        lastSample = nil
    }
}
