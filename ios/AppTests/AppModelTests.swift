import XCTest
import NimbusKit
@testable import NimbusVPN

/// App-layer tests that run in the iOS simulator via Xcode (`NimbusVPNTests`
/// target). The exhaustive core coverage lives in `NimbusKitTests` and runs
/// anywhere with `swift test`.
@MainActor
final class AppModelTests: XCTestCase {
    private func makeModel() -> AppModel {
        AppModel(services: .makeSimulated())
    }

    func testDefaultAppearance() {
        let model = makeModel()
        XCTAssertEqual(model.theme, .dark)
        XCTAssertEqual(model.accent, .blue)
        XCTAssertEqual(model.palette.theme, .dark)
    }

    func testThemeCycles() {
        let model = makeModel()
        model.cycleTheme()
        XCTAssertEqual(model.theme, .light)
        model.cycleTheme()
        XCTAssertEqual(model.theme, .amoled)
        model.cycleTheme()
        XCTAssertEqual(model.theme, .dark)
    }

    func testLibraryLoadsSeedData() async {
        let model = makeModel()
        await model.start()
        XCTAssertFalse(model.configs.isEmpty)
        XCTAssertFalse(model.folders.isEmpty)
        XCTAssertGreaterThanOrEqual(model.filterChips.count, 3)
    }

    func testVisibleConfigsRespectsSearch() async {
        let model = makeModel()
        await model.start()
        model.searchText = "frankfurt"
        XCTAssertEqual(model.visibleConfigs.count, 1)
    }
}
