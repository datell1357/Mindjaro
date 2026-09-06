import Foundation
import MaeumjaroDomain

func runAnalyticsProbe(_ arguments: ProbeArguments) throws -> ProbeResponse {
    guard Set(arguments.options.keys).isSubset(of: ["fixture", "access"]), arguments.flags.isEmpty else {
        throw ProbeCommandError.invalidArguments(command: "analytics", detail: "unsupported-option")
    }
    guard arguments.value(for: "fixture") == "timezone-boundaries" else {
        throw ProbeCommandError.invalidArguments(command: "analytics", detail: "unsupported-fixture")
    }
    let access = arguments.value(for: "access") ?? "free"
    guard access == "free" || access == "pro" else {
        throw ProbeCommandError.invalidArguments(command: "analytics", detail: "unsupported-access")
    }

    let policy = FeatureAccessPolicy(entitlement: access == "pro" ? .pro : .free)
    let today = AnalyticsFixture.today
    guard let period = policy.historyWindow(today: today) else {
        throw ProbeCommandError.invalidArguments(command: "analytics", detail: "invalid-reference-date")
    }

    let events = AnalyticsFixture.events
    let report = AnalyticsAggregator().aggregate(events: events, period: period)
    let expectation = AnalyticsFixture.expectation(for: access)
    let matches = expectation.matches(report: report)
    let visibleDates = period.dates.compactMap { report.daily[$0] }

    return ProbeResponse(
        command: "analytics",
        status: matches ? "ok" : "mismatch",
        data: [
            "fixture": .string("timezone-boundaries"),
            "access": .string(access),
            "today": .string(today),
            "retainedEventCount": .integer(events.count),
            "visibleDateCount": .integer(visibleDates.count),
            "actual": reportValue(report),
            "expected": expectation.value,
            "matches": .boolean(matches)
        ]
    )
}

private enum AnalyticsFixture {
    static let today = "2028-11-05"

    static let events: [InjectionEvent] = {
        let previousRows: [(String, String, Int, Int)] = (0..<15).map { index in
            ("2028-09-11", "2028-09-11T12:00:00Z", 0, (index % 5) + 1)
        }
        let recentRows: [(String, String, Int, Int)] = (0..<15).map { index in
            ("2028-10-09", "2028-10-09T12:00:00Z", 0, (index % 5) + 1)
        }
        let boundaryRows: [(String, String, Int, Int)] = [
            ("2028-02-29", "2028-02-29T12:00:00Z", 0, 5),
            ("2028-03-12", "2028-03-12T06:59:00Z", -300, 2),
            ("2028-03-12", "2028-03-12T07:01:00Z", -240, 3),
            ("2028-10-08", "2028-10-07T10:05:00Z", 840, 4),
            ("2028-10-07", "2028-10-08T11:59:00Z", -720, 4),
            ("2028-11-05", "2028-11-05T05:30:00Z", -240, 5),
            ("2028-11-05", "2028-11-05T06:30:00Z", -300, 5),
            ("2028-10-20", "2028-10-21T12:00:00Z", 0, 2),
            ("2028-10-20", "2028-10-20T12:00:00Z", 0, 2),
            ("malformed", "2028-11-01T12:00:00Z", 540, 3),
            ("2028-11-06", "2028-11-06T12:00:00Z", 540, 3),
            ("2028-11-01", "2028-11-01T12:00:00Z", 900, 3)
        ]
        let rows = previousRows + recentRows + boundaryRows
        return rows.enumerated().map { index, row in
            let date = ISO8601DateFormatter().date(from: row.1)!
            return InjectionEvent(
                id: UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", index + 1))!,
                startedAtUTC: date.addingTimeInterval(-1),
                completedAtUTC: date,
                createdAtUTC: date,
                eventLocalDate: row.0,
                timezoneOffsetMinutes: row.2,
                intensity: Intensity(rawValue: row.3)!,
                source: .app,
                phraseID: "fixture.analytics.\(index + 1)",
                animationDurationMilliseconds: 1200,
                interruptedCount: 0,
                appVersion: "fixture"
            )
        }
    }()

    static func expectation(for access: String) -> AnalyticsExpectation {
        if access == "pro" {
            return AnalyticsExpectation(
                startDate: "2027-11-08",
                endDate: "2028-11-05",
                viewportStartDate: "2028-07-17",
                viewportEndDate: "2028-11-05",
                totalCount: 39,
                totalIntensity: 122,
                activeDays: 8,
                threeHourCounts: [4, 1, 0, 0, 33, 0, 0, 1],
                weekdayCounts: [30, 1, 0, 0, 2, 1, 5],
                intensityCounts: [6, 9, 7, 8, 9],
                sampleTier: .comparison,
                recentComparison: (19, 59, 3),
                previousComparison: (17, 53, 3),
                nonZeroDays: [
                    ("2028-02-29", 1, 5),
                    ("2028-03-12", 2, 5),
                    ("2028-09-11", 15, 45),
                    ("2028-10-07", 1, 4),
                    ("2028-10-08", 1, 4),
                    ("2028-10-09", 15, 45),
                    ("2028-10-20", 2, 4),
                    ("2028-11-05", 2, 10)
                ]
            )
        }
        return AnalyticsExpectation(
            startDate: "2028-10-07",
            endDate: "2028-11-05",
            viewportStartDate: "2028-10-07",
            viewportEndDate: "2028-11-05",
            totalCount: 21,
            totalIntensity: 67,
            activeDays: 5,
            threeHourCounts: [3, 0, 0, 0, 17, 0, 0, 1],
            weekdayCounts: [15, 0, 0, 0, 2, 1, 3],
            intensityCounts: [3, 5, 3, 5, 5],
            sampleTier: .patterns,
            recentComparison: nil,
            previousComparison: nil,
            nonZeroDays: [
                ("2028-10-07", 1, 4),
                ("2028-10-08", 1, 4),
                ("2028-10-09", 15, 45),
                ("2028-10-20", 2, 4),
                ("2028-11-05", 2, 10)
            ]
        )
    }
}

private struct AnalyticsExpectation {
    let startDate: String
    let endDate: String
    let viewportStartDate: String
    let viewportEndDate: String
    let totalCount: Int
    let totalIntensity: Int
    let activeDays: Int
    let threeHourCounts: [Int]
    let weekdayCounts: [Int]
    let intensityCounts: [Int]
    let sampleTier: SampleTier
    let recentComparison: (Int, Int, Int)?
    let previousComparison: (Int, Int, Int)?
    let nonZeroDays: [(String, Int, Int)]

    var value: ProbeJSONValue {
        .object([
            "period": .object([
                "startDate": .string(startDate),
                "endDate": .string(endDate),
                "viewportStartDate": .string(viewportStartDate),
                "viewportEndDate": .string(viewportEndDate)
            ]),
            "totalCount": .integer(totalCount),
            "totalIntensity": .integer(totalIntensity),
            "activeDays": .integer(activeDays),
            "threeHourCounts": intArray(threeHourCounts),
            "weekdayCounts": intArray(weekdayCounts),
            "intensityCounts": intArray(intensityCounts),
            "sampleTier": .string(sampleTier.rawValue),
            "nonZeroDays": .array(nonZeroDays.map { date, count, sum in
                .object(["date": .string(date), "count": .integer(count), "intensitySum": .integer(sum)])
            }),
            "comparison": comparisonValue(recent: recentComparison, previous: previousComparison)
        ])
    }

    func matches(report: AnalyticsReport) -> Bool {
        guard report.period.startDate == startDate,
              report.period.endDate == endDate,
              report.period.viewportStartDate == viewportStartDate,
              report.period.viewportEndDate == viewportEndDate,
              report.totalCount == totalCount,
              report.totalIntensity == totalIntensity,
              report.activeDays == activeDays,
              report.threeHourCounts == threeHourCounts,
              report.weekdayCounts == weekdayCounts,
              report.intensityCounts == intensityCounts,
              report.sampleTier == sampleTier else {
            return false
        }

        guard nonZeroDays.allSatisfy({ date, count, sum in
            report.daily[date]?.count == count && report.daily[date]?.intensitySum == sum
        }) else {
            return false
        }

        let actualNonZeroDays = report.daily.values.filter { $0.count > 0 }.count
        guard actualNonZeroDays == nonZeroDays.count else { return false }

        guard comparisonMatches(report.comparison, expected: recentComparison, previous: previousComparison) else {
            return false
        }
        return true
    }
}

private func reportValue(_ report: AnalyticsReport) -> ProbeJSONValue {
    .object([
        "period": .object([
            "plan": .string(report.period.plan.rawValue),
            "startDate": .string(report.period.startDate),
            "endDate": .string(report.period.endDate),
            "todayDate": .string(report.period.todayDate),
            "viewportStartDate": .string(report.period.viewportStartDate),
            "viewportEndDate": .string(report.period.viewportEndDate)
        ]),
        "daily": .array(report.period.dates.compactMap { date in
            guard let daily = report.daily[date] else { return nil }
            return .object([
                "date": .string(daily.localDate),
                "count": .integer(daily.count),
                "intensitySum": .integer(daily.intensitySum)
            ])
        }),
        "totalCount": .integer(report.totalCount),
        "totalIntensity": .integer(report.totalIntensity),
        "activeDays": .integer(report.activeDays),
        "activeDayAverage": .double(report.activeDayAverage),
        "averageIntensity": .double(report.averageIntensity),
        "threeHourCounts": intArray(report.threeHourCounts),
        "weekdayCounts": intArray(report.weekdayCounts),
        "intensityCounts": intArray(report.intensityCounts),
        "sampleTier": .string(report.sampleTier.rawValue),
        "comparison": report.comparison.map(comparisonValue) ?? .null
    ])
}

private func intArray(_ values: [Int]) -> ProbeJSONValue {
    .array(values.map { .integer($0) })
}

private func comparisonValue(
    recent: (Int, Int, Int)?,
    previous: (Int, Int, Int)?
) -> ProbeJSONValue {
    guard let recent, let previous else { return .null }
    return .object([
        "recent": summaryValue(recent),
        "previous": summaryValue(previous)
    ])
}

private func comparisonValue(_ comparison: AnalyticsComparison) -> ProbeJSONValue {
    .object([
        "recent": summaryValue(comparison.recent),
        "previous": summaryValue(comparison.previous)
    ])
}

private func summaryValue(_ summary: AnalyticsPeriodSummary) -> ProbeJSONValue {
    .object([
        "count": .integer(summary.count),
        "intensitySum": .integer(summary.intensitySum),
        "activeDays": .integer(summary.activeDays),
        "activeDayAverage": .double(summary.activeDayAverage)
    ])
}

private func summaryValue(_ summary: (Int, Int, Int)) -> ProbeJSONValue {
    .object([
        "count": .integer(summary.0),
        "intensitySum": .integer(summary.1),
        "activeDays": .integer(summary.2),
        "activeDayAverage": .double(summary.2 == 0 ? 0 : Double(summary.0) / Double(summary.2))
    ])
}

private func comparisonMatches(
    _ actual: AnalyticsComparison?,
    expected recent: (Int, Int, Int)?,
    previous: (Int, Int, Int)?
) -> Bool {
    guard let recent, let previous else { return actual == nil }
    guard let actual else { return false }
    return actual.recent.count == recent.0
        && actual.recent.intensitySum == recent.1
        && actual.recent.activeDays == recent.2
        && actual.previous.count == previous.0
        && actual.previous.intensitySum == previous.1
        && actual.previous.activeDays == previous.2
}
