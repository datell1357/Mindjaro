import MaeumjaroDomain
import XCTest
@testable import Maeumjaro

final class HistoryViewModelTests: XCTestCase {
    func testAccessibilityContentUsesExactEmptySummaryValues() {
        let window = try! XCTUnwrap(HistoryWindow.free(today: "2026-09-05"))
        let report = AnalyticsAggregator().aggregate(events: [], period: window)
        let content = HistoryAccessibilityContent.make(report: report)
        XCTAssertEqual(content.summary.map(\.value), ["0회", "0", "0.0회"])
        XCTAssertEqual(content.dates.count, 30)
        XCTAssertFalse(content.dates.contains { $0.label == "2026-08-06" })
    }

    func testFreePolicyDoesNotExposeProAnalytics() {
        let policy = FeatureAccessPolicy(entitlement: .free)
        XCTAssertFalse(policy.canAccess(.heatmap))
        XCTAssertTrue(policy.canAccess(.basicHistory))
        XCTAssertEqual(policy.historyWindow(today: "2026-09-05")?.plan, .free)
    }
}
