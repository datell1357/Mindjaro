import Foundation

public enum HeatmapMetric: String, Codable, CaseIterable, Hashable, Sendable {
    case count
    case intensitySum

    public var displayName: String {
        Bundle.module.localizedString(forKey: "analytics.metric.\(rawValue)", value: rawValue == "count" ? "횟수" : "강도 합", table: nil)
    }
}

public enum CountBucket: String, Codable, CaseIterable, Hashable, Sendable {
    case zero
    case one
    case two
    case threeToFour
    case fiveToSix
    case sevenOrMore

    public var displayName: String {
        let fallback = ["zero": "0회", "one": "1회", "two": "2회", "threeToFour": "3–4회", "fiveToSix": "5–6회", "sevenOrMore": "7회 이상"][rawValue] ?? rawValue
        return Bundle.module.localizedString(forKey: "analytics.countBucket.\(rawValue)", value: fallback, table: nil)
    }
}

public enum IntensitySumBucket: String, Codable, CaseIterable, Hashable, Sendable {
    case zero
    case oneToThree
    case fourToSeven
    case eightToTwelve
    case thirteenToNineteen
    case twentyOrMore

    public var displayName: String {
        let fallback = ["zero": "0", "oneToThree": "1–3", "fourToSeven": "4–7", "eightToTwelve": "8–12", "thirteenToNineteen": "13–19", "twentyOrMore": "20 이상"][rawValue] ?? rawValue
        return Bundle.module.localizedString(forKey: "analytics.intensitySumBucket.\(rawValue)", value: fallback, table: nil)
    }
}

public enum SampleTier: String, Codable, CaseIterable, Hashable, Sendable {
    case insufficient
    case facts
    case patterns
    case comparison

    public var displayName: String {
        let fallback = ["insufficient": "기록 부족", "facts": "기본 사실", "patterns": "패턴", "comparison": "비교"][rawValue] ?? rawValue
        return Bundle.module.localizedString(forKey: "analytics.sampleTier.\(rawValue)", value: fallback, table: nil)
    }
}

public struct DailyAnalytics: Codable, Equatable, Hashable, Sendable {
    public let localDate: String
    public let count: Int
    public let intensitySum: Int

    public init(localDate: String, count: Int, intensitySum: Int) {
        self.localDate = localDate
        self.count = count
        self.intensitySum = intensitySum
    }

    public var averageIntensity: Double {
        count == 0 ? 0 : Double(intensitySum) / Double(count)
    }

    public var countBucket: CountBucket {
        HeatmapScale.countBucket(for: count)
    }

    public var intensitySumBucket: IntensitySumBucket {
        HeatmapScale.intensitySumBucket(for: intensitySum)
    }
}

public struct AnalyticsPeriodSummary: Codable, Equatable, Hashable, Sendable {
    public let count: Int
    public let intensitySum: Int
    public let activeDays: Int

    public init(count: Int, intensitySum: Int, activeDays: Int) {
        self.count = count
        self.intensitySum = intensitySum
        self.activeDays = activeDays
    }

    public var activeDayAverage: Double {
        activeDays == 0 ? 0 : Double(count) / Double(activeDays)
    }
}

public struct AnalyticsComparison: Codable, Equatable, Hashable, Sendable {
    public let recent: AnalyticsPeriodSummary
    public let previous: AnalyticsPeriodSummary

    public init(recent: AnalyticsPeriodSummary, previous: AnalyticsPeriodSummary) {
        self.recent = recent
        self.previous = previous
    }
}

public struct AnalyticsReport: Codable, Equatable, Sendable {
    public let period: HistoryWindow
    public let daily: [String: DailyAnalytics]
    public let totalCount: Int
    public let totalIntensity: Int
    public let activeDays: Int
    public let threeHourCounts: [Int]
    public let weekdayCounts: [Int]
    public let intensityCounts: [Int]
    public let sampleTier: SampleTier
    public let comparison: AnalyticsComparison?

    public init(
        period: HistoryWindow,
        daily: [String: DailyAnalytics],
        totalCount: Int,
        totalIntensity: Int,
        activeDays: Int,
        threeHourCounts: [Int],
        weekdayCounts: [Int],
        intensityCounts: [Int],
        sampleTier: SampleTier,
        comparison: AnalyticsComparison?
    ) {
        self.period = period
        self.daily = daily
        self.totalCount = totalCount
        self.totalIntensity = totalIntensity
        self.activeDays = activeDays
        self.threeHourCounts = threeHourCounts
        self.weekdayCounts = weekdayCounts
        self.intensityCounts = intensityCounts
        self.sampleTier = sampleTier
        self.comparison = comparison
    }

    public var activeDayAverage: Double {
        activeDays == 0 ? 0 : Double(totalCount) / Double(activeDays)
    }

    public var averageIntensity: Double {
        totalCount == 0 ? 0 : Double(totalIntensity) / Double(totalCount)
    }

    public var hourlyCounts: [Int] {
        threeHourCounts
    }
}

public typealias DailySummary = DailyAnalytics
public typealias AnalyticsResult = AnalyticsReport
