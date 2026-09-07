import XCTest
import MaeumjaroDomain
import MaeumjaroShared

final class WidgetSnapshotTests: XCTestCase {
    func testAccessibilityContentHasExactStrengthSummaryAndHints() {
        let summary = TodaySummarySnapshot(localDate: "2026-09-05", completionCount: 3, intensitySum: 11, writer: .app, updatedAt: Date(), revision: 1)
        let small = WidgetAccessibilityContent.small(strength: .one, summary: summary)
        XCTAssertEqual(small.label, "마음자로 오늘 위젯")
        XCTAssertEqual(small.value, "강도 1, 오늘 3회")
        XCTAssertFalse(small.hint.isEmpty)
        XCTAssertFalse(small.hint.contains("빼기"))
        XCTAssertTrue(small.hint.contains("앱 설정"))

        let medium = WidgetAccessibilityContent.medium(strength: .five, summary: summary)
        XCTAssertEqual(medium.value, "현재 강도 5, 오늘 3회")
        XCTAssertFalse(medium.hint.isEmpty)
    }

    func testSmallAndMediumEntriesShareTheSameSnapshotValues() {
        let summary = TodaySummarySnapshot(localDate: "2026-09-05", completionCount: 2, intensitySum: 7, writer: .app, updatedAt: Date(), revision: 1)
        let entry = MaeumjaroTimelineEntry(date: Date(), strength: .five, today: summary, theme: .midnightInk, isPlaceholder: false)
        XCTAssertEqual(entry.strength, .five)
        XCTAssertEqual(entry.today.sum, 7)
        XCTAssertEqual(entry.theme, .midnightInk)
        XCTAssertGreaterThanOrEqual(DesignTokens.minimumTouchTarget, 44)
    }
}
