import Foundation
import Testing

import MaeumjaroDomain

@Test
func aggregateUsesStoredLocalDatesAndActiveDayDenominator() throws {
    let events = [
        makeEvent(id: 1, localDate: "2026-09-05", completedAt: "2026-09-05T00:20:00Z", offset: 540, intensity: 2),
        makeEvent(id: 2, localDate: "2026-09-05", completedAt: "2026-09-05T01:20:00Z", offset: 540, intensity: 4),
        makeEvent(id: 3, localDate: "2026-09-04", completedAt: "2026-09-04T23:30:00Z", offset: -720, intensity: 5)
    ]
    let period = try #require(HistoryWindow.free(today: "2026-09-05"))

    let report = AnalyticsAggregator().aggregate(events: events, period: period)

    #expect(report.totalCount == 3)
    #expect(report.totalIntensity == 11)
    #expect(report.activeDays == 2)
    #expect(report.activeDayAverage == 1.5)
    #expect(report.daily["2026-09-05"]?.count == 2)
    #expect(report.daily["2026-09-05"]?.intensitySum == 6)
    #expect(report.daily["2026-09-05"]?.averageIntensity == 3)
    #expect(report.daily["2026-09-04"]?.count == 1)
}

@Test
func aggregateKeepsRowsOutOfRangeAndDoesNotRewriteStoredDate() throws {
    let events = [
        makeEvent(id: 1, localDate: "2026-08-06", completedAt: "2026-08-06T23:59:00Z", offset: 540, intensity: 1),
        makeEvent(id: 2, localDate: "2026-09-06", completedAt: "2026-09-06T00:01:00Z", offset: 540, intensity: 5),
        makeEvent(id: 3, localDate: "not-a-date", completedAt: "2026-09-05T00:01:00Z", offset: 540, intensity: 3)
    ]
    let period = try #require(HistoryWindow.free(today: "2026-09-05"))

    let report = AnalyticsAggregator().aggregate(events: events, period: period)

    #expect(report.totalCount == 0)
    #expect(report.daily.count == 30)
    #expect(events.map(\.eventLocalDate) == ["2026-08-06", "2026-09-06", "not-a-date"])
}

@Test
func aggregateUsesEightThreeHourBucketsAndMondayFirstWeekdays() throws {
    let events = (0..<8).map { index in
        makeEvent(
            id: index + 1,
            localDate: "2026-09-07",
            completedAt: "2026-09-07T\(String(format: "%02d", index * 3)):00:00Z",
            offset: 0,
            intensity: 2
        )
    }
    let period = try #require(HistoryWindow.free(today: "2026-09-07"))

    let report = AnalyticsAggregator().aggregate(events: events, period: period)

    #expect(report.threeHourCounts == [1, 1, 1, 1, 1, 1, 1, 1])
    #expect(report.weekdayCounts == [8, 0, 0, 0, 0, 0, 0])
    #expect(report.intensityCounts == [0, 8, 0, 0, 0])
}

@Test
func aggregateUsesFixedHeatmapBucketsAndNeutralSampleTiers() throws {
    let period = try #require(HistoryWindow.free(today: "2026-09-05"))
    let one = AnalyticsAggregator().aggregate(
        events: [makeEvent(id: 1, localDate: "2026-09-05", completedAt: "2026-09-05T12:00:00Z", offset: 0, intensity: 1)],
        period: period
    )
    let five = AnalyticsAggregator().aggregate(
        events: (0..<5).map { makeEvent(id: $0 + 1, localDate: "2026-09-05", completedAt: "2026-09-05T12:00:00Z", offset: 0, intensity: 1) },
        period: period
    )
    let ten = AnalyticsAggregator().aggregate(
        events: (0..<10).map { makeEvent(id: $0 + 1, localDate: "2026-09-05", completedAt: "2026-09-05T12:00:00Z", offset: 0, intensity: 1) },
        period: period
    )

    #expect(one.sampleTier == .insufficient)
    #expect(one.daily["2026-09-05"]?.countBucket == .one)
    #expect(one.daily["2026-09-05"]?.intensitySumBucket == .oneToThree)
    #expect(five.sampleTier == .facts)
    #expect(ten.sampleTier == .patterns)
    #expect(HeatmapScale.countLevel(for: 7) == .sevenOrMore)
    #expect(HeatmapScale.intensityLevel(for: 20) == .twentyOrMore)
}

@Test
func aggregateProvidesFourWeekComparisonOnlyAtThirtyEvents() throws {
    let period = try #require(HistoryWindow.pro(today: "2026-09-06"))
    let events = (0..<30).map { index in
        let date = index < 15 ? "2026-08-01" : "2026-09-01"
        return makeEvent(id: index + 1, localDate: date, completedAt: "2026-09-01T12:00:00Z", offset: 0, intensity: 2)
    }

    let report = AnalyticsAggregator().aggregate(events: events, period: period)

    #expect(report.sampleTier == .comparison)
    #expect(report.comparison?.recent.count == 15)
    #expect(report.comparison?.previous.count == 15)
    #expect(report.comparison?.recent.intensitySum == 30)
    #expect(report.comparison?.previous.intensitySum == 30)
}

@Test
func aggregateAcceptsLeapDayAndUtcBoundaryOffsetsWithoutCurrentTimezone() throws {
    let events = [
        makeEvent(id: 1, localDate: "2024-02-29", completedAt: "2024-02-29T23:59:00Z", offset: 840, intensity: 5),
        makeEvent(id: 2, localDate: "2024-02-28", completedAt: "2024-02-29T00:01:00Z", offset: -720, intensity: 4)
    ]
    let period = try #require(HistoryWindow.free(today: "2024-02-29"))

    let report = AnalyticsAggregator().aggregate(events: events, period: period)

    #expect(report.totalCount == 2)
    #expect(report.daily["2024-02-29"]?.count == 1)
    #expect(report.daily["2024-02-28"]?.count == 1)
    #expect(report.weekdayCounts[3] == 1)
}

@Test
func aggregateKeepsStoredDateAcrossDSTCrossMidnightAndClockRollback() throws {
    let events = [
        makeEvent(id: 1, localDate: "2024-03-10", completedAt: "2024-03-10T07:30:00Z", offset: -300, intensity: 1),
        makeEvent(id: 2, localDate: "2024-03-10", completedAt: "2024-03-10T07:30:00Z", offset: 840, intensity: 2),
        makeEvent(id: 3, localDate: "2024-03-10", completedAt: "2024-03-11T00:05:00Z", offset: -720, intensity: 3),
        makeEvent(id: 4, localDate: "2024-03-09", completedAt: "2024-03-10T00:05:00Z", offset: -720, intensity: 4)
    ]
    let period = try #require(HistoryWindow.free(today: "2024-03-10"))

    let report = AnalyticsAggregator().aggregate(events: events, period: period)

    #expect(report.totalCount == 4)
    #expect(report.totalIntensity == 10)
    #expect(report.daily["2024-03-10"]?.count == 3)
    #expect(report.daily["2024-03-09"]?.count == 1)
    #expect(report.threeHourCounts == [1, 0, 0, 0, 2, 0, 0, 1])
}

@Test
func emptyAggregateUsesZeroForEmptyActiveDayDenominator() throws {
    let period = try #require(HistoryWindow.free(today: "2024-03-10"))

    let report = AnalyticsAggregator().aggregate(events: [], period: period)

    #expect(report.totalCount == 0)
    #expect(report.totalIntensity == 0)
    #expect(report.activeDays == 0)
    #expect(report.activeDayAverage == 0)
    #expect(report.averageIntensity == 0)
    #expect(report.threeHourCounts == Array(repeating: 0, count: 8))
    #expect(report.weekdayCounts == Array(repeating: 0, count: 7))
    #expect(report.intensityCounts == Array(repeating: 0, count: 5))
    #expect(report.comparison == nil)
}

private func makeEvent(
    id: Int,
    localDate: String,
    completedAt: String,
    offset: Int,
    intensity: Int
) -> InjectionEvent {
    let formatter = ISO8601DateFormatter()
    let date = formatter.date(from: completedAt) ?? Date(timeIntervalSince1970: 0)
    return InjectionEvent(
        id: UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", id))!,
        startedAtUTC: date.addingTimeInterval(-1),
        completedAtUTC: date,
        createdAtUTC: date,
        eventLocalDate: localDate,
        timezoneOffsetMinutes: offset,
        intensity: Intensity(rawValue: intensity)!,
        source: .app,
        phraseID: "fixture.\(id)",
        animationDurationMilliseconds: 1200,
        interruptedCount: 0,
        appVersion: "fixture"
    )
}
