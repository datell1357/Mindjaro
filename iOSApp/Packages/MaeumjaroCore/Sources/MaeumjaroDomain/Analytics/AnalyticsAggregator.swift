import Foundation

public struct AnalyticsAggregator: Sendable {
    public init() {}

    public func aggregate(events: [InjectionEvent], period: HistoryWindow) -> AnalyticsReport {
        let validEvents = events.compactMap { event -> (InjectionEvent, AnalyticsDate)? in
            guard let localDate = AnalyticsDate(event.eventLocalDate),
                  localDate.rawValue >= period.startDate,
                  localDate.rawValue <= period.endDate,
                  localDate.rawValue <= period.todayDate,
                  (-720...840).contains(event.timezoneOffsetMinutes) else {
                return nil
            }
            return (event, localDate)
        }

        var dailyCounts = Dictionary(uniqueKeysWithValues: period.dates.map { ($0, 0) })
        var dailyIntensity = dailyCounts
        var threeHourCounts = Array(repeating: 0, count: 8)
        var weekdayCounts = Array(repeating: 0, count: 7)
        var intensityCounts = Array(repeating: 0, count: 5)

        for (event, localDate) in validEvents {
            dailyCounts[localDate.rawValue, default: 0] += 1
            dailyIntensity[localDate.rawValue, default: 0] += event.intensity.rawValue
            weekdayCounts[localDate.weekdayIndexMondayFirst] += 1
            intensityCounts[event.intensity.rawValue - 1] += 1

            let localHour = Calendar.utc.component(
                .hour,
                from: event.completedAtUTC.addingTimeInterval(Double(event.timezoneOffsetMinutes) * 60)
            )
            threeHourCounts[min(localHour / 3, threeHourCounts.count - 1)] += 1
        }

        let daily = dailyCounts.reduce(into: [String: DailyAnalytics]()) { result, entry in
            result[entry.key] = DailyAnalytics(
                localDate: entry.key,
                count: entry.value,
                intensitySum: dailyIntensity[entry.key, default: 0]
            )
        }
        let totalCount = validEvents.count
        let totalIntensity = validEvents.reduce(0) { $0 + $1.0.intensity.rawValue }
        let activeDays = daily.values.filter { $0.count > 0 }.count
        let sampleTier = SampleTier.tier(for: totalCount)
        let comparison = sampleTier == .comparison ? makeComparison(validEvents: validEvents, period: period) : nil

        return AnalyticsReport(
            period: period,
            daily: daily,
            totalCount: totalCount,
            totalIntensity: totalIntensity,
            activeDays: activeDays,
            threeHourCounts: threeHourCounts,
            weekdayCounts: weekdayCounts,
            intensityCounts: intensityCounts,
            sampleTier: sampleTier,
            comparison: comparison
        )
    }

    public func aggregate(_ events: [InjectionEvent], period: HistoryWindow) -> AnalyticsReport {
        aggregate(events: events, period: period)
    }

    private func makeComparison(
        validEvents: [(InjectionEvent, AnalyticsDate)],
        period: HistoryWindow
    ) -> AnalyticsComparison? {
        guard period.plan == .pro,
              let currentMonday = AnalyticsDate(period.currentWeekStartDate),
              let recentStart = currentMonday.addingDays(-21),
              let recentEnd = currentMonday.addingDays(6),
              let previousStart = currentMonday.addingDays(-49),
              let previousEnd = currentMonday.addingDays(-22) else {
            return nil
        }

        let recent = validEvents.filter { recentStart...recentEnd ~= $0.1 }
        let previous = validEvents.filter { previousStart...previousEnd ~= $0.1 }
        return AnalyticsComparison(
            recent: summary(for: recent),
            previous: summary(for: previous)
        )
    }

    private func summary(for events: [(InjectionEvent, AnalyticsDate)]) -> AnalyticsPeriodSummary {
        let activeDates = Set(events.map { $0.1.rawValue })
        return AnalyticsPeriodSummary(
            count: events.count,
            intensitySum: events.reduce(0) { $0 + $1.0.intensity.rawValue },
            activeDays: activeDates.count
        )
    }
}

private extension Calendar {
    static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }
}

private extension SampleTier {
    static func tier(for count: Int) -> Self {
        switch count {
        case 0...4: .insufficient
        case 5...9: .facts
        case 10...29: .patterns
        default: .comparison
        }
    }
}
