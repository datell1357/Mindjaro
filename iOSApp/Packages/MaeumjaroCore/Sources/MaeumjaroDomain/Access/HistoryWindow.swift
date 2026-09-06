import Foundation

public struct AnalyticsDate: RawRepresentable, Codable, Comparable, Hashable, Sendable {
    public let rawValue: String

    public init?(rawValue: String) {
        let bytes = Array(rawValue.utf8)
        guard bytes.count == 10, bytes[4] == 45, bytes[7] == 45 else { return nil }

        let year = Self.number(bytes[0..<4])
        let month = Self.number(bytes[5..<7])
        let day = Self.number(bytes[8..<10])
        guard let year, let month, let day, year >= 1, month >= 1, month <= 12, day >= 1 else {
            return nil
        }

        var components = DateComponents()
        components.calendar = Self.calendar
        components.timeZone = Self.calendar.timeZone
        components.year = year
        components.month = month
        components.day = day
        guard let date = Self.calendar.date(from: components),
              Self.calendar.dateComponents([.year, .month, .day], from: date).year == year,
              Self.calendar.dateComponents([.year, .month, .day], from: date).month == month,
              Self.calendar.dateComponents([.year, .month, .day], from: date).day == day else {
            return nil
        }

        self.rawValue = rawValue
    }

    public init?(_ rawValue: String) {
        self.init(rawValue: rawValue)
    }

    public static func < (lhs: AnalyticsDate, rhs: AnalyticsDate) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public func addingDays(_ days: Int) -> AnalyticsDate? {
        guard let date = date,
              let shifted = Self.calendar.date(byAdding: .day, value: days, to: date) else {
            return nil
        }
        return Self(Self.formatter.string(from: shifted))
    }

    public var date: Date? {
        var components = DateComponents()
        components.calendar = Self.calendar
        components.timeZone = Self.calendar.timeZone
        components.year = Int(rawValue.prefix(4))
        components.month = Int(rawValue.dropFirst(5).prefix(2))
        components.day = Int(rawValue.suffix(2))
        return Self.calendar.date(from: components)
    }

    public var weekdayMondayFirst: Int {
        guard let date else { return 0 }
        let sundayFirst = Self.calendar.component(.weekday, from: date)
        return ((sundayFirst + 5) % 7) + 1
    }

    public var weekdayIndexMondayFirst: Int { weekdayMondayFirst - 1 }

    public static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Self.calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Self.calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func number(_ bytes: ArraySlice<UInt8>) -> Int? {
        guard bytes.allSatisfy({ $0 >= 48 && $0 <= 57 }) else { return nil }
        return bytes.reduce(0) { $0 * 10 + Int($1 - 48) }
    }
}

public enum HistoryPlan: String, Codable, CaseIterable, Hashable, Sendable {
    case free
    case pro
}

public struct HistoryWindow: Codable, Equatable, Hashable, Sendable {
    public static let freeDayCount = 30
    public static let proWeekCount = 52
    public static let initialViewportWeekCount = 16

    public let plan: HistoryPlan
    public let startDate: String
    public let endDate: String
    public let todayDate: String
    public let viewportStartDate: String
    public let viewportEndDate: String

    public init?(plan: HistoryPlan, today: String) {
        guard let todayDate = AnalyticsDate(today) else { return nil }

        switch plan {
        case .free:
            guard let start = todayDate.addingDays(-(Self.freeDayCount - 1)) else { return nil }
            self.plan = plan
            self.startDate = start.rawValue
            self.endDate = todayDate.rawValue
            self.todayDate = todayDate.rawValue
            self.viewportStartDate = start.rawValue
            self.viewportEndDate = todayDate.rawValue
        case .pro:
            guard let monday = Self.monday(onOrBefore: todayDate),
                  let start = monday.addingDays(-7 * (Self.proWeekCount - 1)),
                  let end = monday.addingDays(6),
                  let viewportStart = monday.addingDays(-7 * (Self.initialViewportWeekCount - 1)) else {
                return nil
            }
            self.plan = plan
            self.startDate = start.rawValue
            self.endDate = end.rawValue
            self.todayDate = todayDate.rawValue
            self.viewportStartDate = viewportStart.rawValue
            self.viewportEndDate = end.rawValue
        }
    }

    public static func free(today: String) -> Self? {
        Self(plan: .free, today: today)
    }

    public static func pro(today: String) -> Self? {
        Self(plan: .pro, today: today)
    }

    public var dates: [String] {
        guard let start = AnalyticsDate(startDate), let end = AnalyticsDate(endDate) else {
            return []
        }
        var result: [String] = []
        var current = start
        while current <= end {
            result.append(current.rawValue)
            guard let next = current.addingDays(1) else { break }
            current = next
        }
        return result
    }

    public func contains(_ localDate: String) -> Bool {
        guard let date = AnalyticsDate(localDate),
              let start = AnalyticsDate(startDate),
              let end = AnalyticsDate(endDate),
              let today = AnalyticsDate(todayDate) else {
            return false
        }
        return start...end ~= date && date <= today
    }

    public var currentWeekStartDate: String {
        guard let today = AnalyticsDate(todayDate), let monday = Self.monday(onOrBefore: today) else {
            return todayDate
        }
        return monday.rawValue
    }

    public var currentWeekEndDate: String {
        guard let monday = AnalyticsDate(currentWeekStartDate), let sunday = monday.addingDays(6) else {
            return todayDate
        }
        return sunday.rawValue
    }

    private static func monday(onOrBefore date: AnalyticsDate) -> AnalyticsDate? {
        date.addingDays(-(date.weekdayMondayFirst - 1))
    }
}
