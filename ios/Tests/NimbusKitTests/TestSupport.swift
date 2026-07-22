import XCTest
@testable import NimbusKit

/// Polls an async condition until it holds or the timeout elapses. Used to await
/// actor state that changes via background tasks (the tunnel event pump).
func eventually(timeout: TimeInterval = 3.0, _ condition: @escaping () async -> Bool) async -> Bool {
    let start = Date()
    while Date().timeIntervalSince(start) < timeout {
        if await condition() { return true }
        try? await Task.sleep(nanoseconds: 5_000_000) // 5ms
    }
    return await condition()
}
