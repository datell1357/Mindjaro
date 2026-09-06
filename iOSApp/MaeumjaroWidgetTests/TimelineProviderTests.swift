import XCTest
import MaeumjaroDomain
import MaeumjaroShared

final class TimelineProviderTests: XCTestCase {
    func testMissingStateFallsBackToStrengthThreeAndTodayZero() {
        let storage = MemoryDataStore()
        let date = fixedDate
        let provider = MaeumjaroTimelineProvider(
            strengthStore: SharedStrengthStore(storage: storage),
            todayStore: TodaySummaryStore(storage: storage),
            themeStore: WidgetThemeStore(storage: storage),
            calendar: fixedCalendar,
            now: { date }
        )
        let entry = provider.entry(at: fixedDate)
        XCTAssertEqual(entry.strength, .three)
        XCTAssertEqual(entry.today.count, 0)
        XCTAssertEqual(entry.today.sum, 0)
        XCTAssertEqual(entry.theme, .quietIvory)
    }

    func testStaleSummaryIsRedactedAndTimelineAdvancesAtLocalMidnight() throws {
        let storage = MemoryDataStore()
        let todayStore = TodaySummaryStore(storage: storage)
        try todayStore.write(TodaySummarySnapshot(localDate: "2020-01-01", completionCount: 8, intensitySum: 22, writer: .app, updatedAt: fixedDate, revision: 1))
        let date = fixedDate
        let provider = MaeumjaroTimelineProvider(todayStore: todayStore, calendar: fixedCalendar, now: { date })
        let entry = provider.entry(at: fixedDate)
        XCTAssertEqual(entry.today.count, 0)
        XCTAssertGreaterThan(provider.entry(at: fixedDate).date, Date(timeIntervalSince1970: 0))
    }

    #if DEBUG && MAEUMJARO_QA_FIXTURES
    func testEntryResolvesTheActiveFixtureNamespaceForEachEntry() throws {
        let defaults = AppGroupDefaults(storage: MemoryDataStore())
        let fixtureA = try XCTUnwrap(DebugFixtureNamespace(fixtureID: "11111111-1111-4111-8111-111111111111"))
        let fixtureB = try XCTUnwrap(DebugFixtureNamespace(fixtureID: "22222222-2222-4222-8222-222222222222"))
        let date = fixedDate

        try TodaySummaryStore(defaults: fixtureA.scopedDefaults(from: defaults)).write(
            TodaySummarySnapshot(localDate: localDate, completionCount: 1, intensitySum: 5, writer: .app, updatedAt: date, revision: 0)
        )
        try TodaySummaryStore(defaults: fixtureB.scopedDefaults(from: defaults)).write(
            TodaySummarySnapshot(localDate: localDate, completionCount: 2, intensitySum: 10, writer: .app, updatedAt: date, revision: 0)
        )

        try DebugFixtureNamespace.select(from: ["-MaeumjaroFixtureID", fixtureA.fixtureID.uuidString], in: defaults)
        let provider = MaeumjaroTimelineProvider(calendar: fixedCalendar, now: { date }, appGroupDefaults: defaults)
        XCTAssertEqual(provider.entry(at: date).today.count, 1)

        try DebugFixtureNamespace.select(from: ["-MaeumjaroFixtureID", fixtureB.fixtureID.uuidString], in: defaults)
        XCTAssertEqual(provider.entry(at: date).today.count, 2)
    }
    #endif

    private var fixedCalendar: Calendar { var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(secondsFromGMT: 9 * 3600)!; return calendar }
    private var fixedDate: Date { Date(timeIntervalSince1970: 1_725_278_400) }
    private var localDate: String { "2024-09-02" }
}
