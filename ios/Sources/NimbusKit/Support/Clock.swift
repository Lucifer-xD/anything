import Foundation

/// An injectable source of "now". Injecting the clock keeps time-dependent logic
/// (session duration, statistics buckets, sync timestamps) deterministic under
/// test — no `Date()` calls scattered through the core.
public protocol DateProviding: Sendable {
    func now() -> Date
}

/// Production clock backed by the system wall clock.
public struct SystemClock: DateProviding {
    public init() {}
    public func now() -> Date { Date() }
}

/// Test clock whose time can be set and advanced deterministically.
public final class MutableClock: DateProviding, @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    public init(_ start: Date = Date(timeIntervalSince1970: 1_700_000_000)) {
        self.current = start
    }

    public func now() -> Date {
        lock.lock(); defer { lock.unlock() }
        return current
    }

    public func advance(by interval: TimeInterval) {
        lock.lock(); defer { lock.unlock() }
        current = current.addingTimeInterval(interval)
    }

    public func set(_ date: Date) {
        lock.lock(); defer { lock.unlock() }
        current = date
    }
}
