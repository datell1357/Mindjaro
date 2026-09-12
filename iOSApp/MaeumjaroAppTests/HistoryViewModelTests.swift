import MaeumjaroDomain
import XCTest
@testable import Maeumjaro

final class HistoryViewModelTests: XCTestCase {
    @MainActor
    func testSettingsWeeklyChartIncludesZeroDaysAndExcludesOlderRecordsAcrossYearBoundary() {
        let window = HistoryWindow.free(today: "2026-01-03")!
        let events = ["2025-12-27", "2025-12-28", "2026-01-03", "2026-01-03"].map { day in
            InjectionEvent(id: UUID(), startedAtUTC: .distantPast, completedAtUTC: .distantPast, createdAtUTC: .distantPast,
                           eventLocalDate: day, timezoneOffsetMinutes: 540, intensity: .three, source: .app,
                           phraseID: "test", animationDurationMilliseconds: 1800, interruptedCount: 0, appVersion: "test")
        }
        let report = AnalyticsAggregator().aggregate(events: events, period: window)
        let days = SettingsHistoryChart.days(in: report)
        XCTAssertEqual(days.map(\.localDate), ["2025-12-28", "2025-12-29", "2025-12-30", "2025-12-31", "2026-01-01", "2026-01-02", "2026-01-03"])
        XCTAssertEqual(days.map(\.count), [1, 0, 0, 0, 0, 0, 2])
        let empty = SettingsHistoryChart.days(in: AnalyticsAggregator().aggregate(events: [], period: window))
        XCTAssertEqual(empty.count, 7)
        XCTAssertTrue(empty.allSatisfy { $0.count == 0 })
    }
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
