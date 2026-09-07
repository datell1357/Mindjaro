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
        XCTAssertTrue(policy.canAccess(.heatmap))
        XCTAssertFalse(policy.canAccess(.detailedPatterns))
        XCTAssertTrue(policy.canAccess(.basicHistory))
        XCTAssertEqual(policy.historyWindow(today: "2026-09-05")?.plan, .free)
    }

    func testFreeGridAlignsWeekdaysWithoutAddingAccessibleDates() {
        for today in ["2026-09-07", "2026-09-06", "2024-03-01", "2026-01-01"] {
            let window = HistoryWindow.free(today: today)!
            let cells = HeatmapGrid.weekAlignedDates(window.dates)
            XCTAssertEqual(cells.compactMap { $0 }, window.dates)
            XCTAssertEqual(cells.compactMap { $0 }.count, 30)
            XCTAssertEqual(cells.count % 7, 0)
            for (index, date) in cells.enumerated() {
                if let date { XCTAssertEqual(index % 7, AnalyticsDate(date)!.weekdayIndexMondayFirst) }
            }
        }
    }
}
