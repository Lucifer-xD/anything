import Foundation

/// A tiny multi-subscriber fan-out over `AsyncStream`. Each `stream()` call
/// returns an independent consumer; `emit` delivers to all live consumers.
/// Used by the tunnel controller, log store and statistics service to publish
/// events to any number of view models.
public actor AsyncBroadcaster<Element: Sendable> {
    private var continuations: [UUID: AsyncStream<Element>.Continuation] = [:]
    /// The most recent element, replayed to new subscribers when `replaysLast`.
    private var last: Element?
    private let replaysLast: Bool

    public init(replaysLast: Bool = false) {
        self.replaysLast = replaysLast
    }

    public func stream() -> AsyncStream<Element> {
        AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation
            if replaysLast, let last { continuation.yield(last) }
            continuation.onTermination = { [weak self] _ in
                Task { await self?.remove(id) }
            }
        }
    }

    public func emit(_ element: Element) {
        last = element
        for continuation in continuations.values { continuation.yield(element) }
    }

    public func finishAll() {
        for continuation in continuations.values { continuation.finish() }
        continuations.removeAll()
    }

    private func remove(_ id: UUID) { continuations[id] = nil }
}
