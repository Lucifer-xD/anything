import XCTest
@testable import NimbusKit

final class StatisticsTests: XCTestCase {
    private func session(_ kind: ProtocolKind, host: String, startOffset: TimeInterval, duration: TimeInterval, rx: UInt64, tx: UInt64) -> SessionRecord {
        let start = Date(timeIntervalSince1970: 1_752_000_000).addingTimeInterval(startOffset)
        return SessionRecord(configID: UUID(), configName: "n", kind: kind, serverHost: host,
                             startedAt: start, endedAt: start.addingTimeInterval(duration), rxBytes: rx, txBytes: tx)
    }

    func testSummary() {
        let sessions = [
            session(.reality, host: "a", startOffset: 0, duration: 100, rx: 1000, tx: 500),
            session(.wireguard, host: "b", startOffset: 200, duration: 300, rx: 3000, tx: 1000),
        ]
        let summary = UsageAggregator.summary(sessions)
        XCTAssertEqual(summary.totalRxBytes, 4000)
        XCTAssertEqual(summary.totalTxBytes, 1500)
        XCTAssertEqual(summary.sessionCount, 2)
        XCTAssertEqual(summary.totalConnectedSeconds, 400)
        XCTAssertEqual(summary.averageSessionSeconds, 200)
        XCTAssertEqual(summary.averageBytesPerSession, (4000 + 1500) / 2)
    }

    func testEmptySummary() {
        XCTAssertEqual(UsageAggregator.summary([]), .empty)
    }

    func testDailyBuckets() {
        let sessions = [
            session(.reality, host: "a", startOffset: 0, duration: 60, rx: 100, tx: 100),
            session(.reality, host: "a", startOffset: 3600, duration: 60, rx: 100, tx: 100),   // same day
            session(.reality, host: "a", startOffset: 86_400 * 2, duration: 60, rx: 100, tx: 100), // +2 days
        ]
        let buckets = UsageAggregator.buckets(sessions, period: .daily, calendar: Calendar(identifier: .gregorian))
        XCTAssertEqual(buckets.count, 2)
        XCTAssertEqual(buckets.map(\.sessionCount).max(), 2)
    }

    func testProtocolAndServerSlices() {
        let sessions = [
            session(.reality, host: "a", startOffset: 0, duration: 60, rx: 100, tx: 0),
            session(.reality, host: "b", startOffset: 60, duration: 60, rx: 300, tx: 0),
            session(.wireguard, host: "a", startOffset: 120, duration: 60, rx: 50, tx: 0),
        ]
        let byProto = UsageAggregator.byProtocol(sessions)
        XCTAssertEqual(byProto.first?.key, "VLESS + Reality") // largest usage first
        XCTAssertEqual(byProto.first?.totalBytes, 400)
        let byServer = UsageAggregator.byServer(sessions)
        XCTAssertEqual(byServer.count, 2)
    }

    func testStatisticsServiceLifecycle() async {
        let clock = MutableClock(Date(timeIntervalSince1970: 1_752_000_000))
        let service = StatisticsService(clock: clock)
        let config = SampleData.configurations[0]
        await service.beginSession(config: config)
        await service.updateOpenSession(rxBytes: 2048, txBytes: 1024, latencyMillis: 30)
        // liveSummary should include the open session.
        let live = await service.liveSummary()
        XCTAssertEqual(live.sessionCount, 1)
        XCTAssertEqual(live.totalBytes, 3072)
        clock.advance(by: 120)
        await service.endSession()
        let all = await service.allSessions()
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.duration, 120)
        XCTAssertNotNil(all.first?.endedAt)
    }
}
