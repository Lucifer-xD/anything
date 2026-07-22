import XCTest
@testable import NimbusKit

final class QueryTests: XCTestCase {
    let configs = SampleData.configurations

    func testFilterAll() {
        let result = ConfigQuery(filter: .all).apply(to: configs)
        XCTAssertEqual(result.count, configs.count)
    }

    func testFilterFavorites() {
        let result = ConfigQuery(filter: .favorites).apply(to: configs)
        XCTAssertTrue(result.allSatisfy { $0.metadata.isFavorite })
        XCTAssertEqual(result.count, configs.filter { $0.metadata.isFavorite }.count)
    }

    func testFilterGroup() {
        let result = ConfigQuery(filter: .group("Subscriptions")).apply(to: configs)
        XCTAssertTrue(result.allSatisfy { $0.metadata.group == "Subscriptions" })
    }

    func testSearchByHostAndTag() {
        XCTAssertEqual(ConfigQuery(searchText: "frankfurt").apply(to: configs).count, 1)
        XCTAssertEqual(ConfigQuery(searchText: "de1.nimbus").apply(to: configs).count, 1)
        XCTAssertTrue(ConfigQuery(searchText: "Streaming").apply(to: configs).count >= 1)
    }

    func testPinnedFloatToTop() {
        let result = ConfigQuery(sort: .name).apply(to: configs)
        // Reality — Frankfurt is pinned in sample data.
        XCTAssertTrue(result.first?.metadata.isPinned == true)
    }

    func testSortByLatency() {
        let unpinned = configs.map { c -> TunnelConfiguration in var x = c; x.metadata.isPinned = false; return x }
        let result = ConfigQuery(sort: .latency).apply(to: unpinned)
        let latencies = result.compactMap { $0.metadata.latencyMillis }
        XCTAssertEqual(latencies, latencies.sorted())
    }

    func testArchivedHiddenByDefault() {
        var archived = configs
        archived[0].metadata.isArchived = true
        let visible = ConfigQuery().apply(to: archived)
        XCTAssertEqual(visible.count, configs.count - 1)
        let all = ConfigQuery(includeArchived: true).apply(to: archived)
        XCTAssertEqual(all.count, configs.count)
    }
}
