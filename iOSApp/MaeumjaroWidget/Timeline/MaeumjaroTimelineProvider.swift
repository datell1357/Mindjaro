import Foundation
import MaeumjaroDomain
import MaeumjaroShared
import WidgetKit

struct MaeumjaroTimelineProvider: TimelineProvider {
    typealias Entry = MaeumjaroTimelineEntry
    private let injectedStrengthStore: SharedStrengthStore?
    private let injectedTodayStore: TodaySummaryStore?
    private let injectedThemeStore: WidgetThemeStore?
    private let appGroupDefaults: AppGroupDefaults
    private let calendar: Calendar
    private let now: () -> Date

    init(strengthStore: SharedStrengthStore? = nil, todayStore: TodaySummaryStore? = nil, themeStore: WidgetThemeStore? = nil, calendar: Calendar = .autoupdatingCurrent, now: @escaping () -> Date = Date.init, appGroupDefaults: AppGroupDefaults? = nil) {
        self.injectedStrengthStore = strengthStore
        self.injectedTodayStore = todayStore
        self.injectedThemeStore = themeStore
        self.appGroupDefaults = appGroupDefaults ?? (try? AppGroupDefaults()) ?? AppGroupDefaults(storage: MemoryDataStore())
        self.calendar = calendar
        self.now = now
    }

    func placeholder(in context: Context) -> Entry {
        let date = now()
        return Entry(date: date, strength: .default, today: .empty(for: localDate(date)), theme: .default, isPlaceholder: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry(at: now()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let date = now()
        completion(Timeline(entries: [entry(at: date)], policy: .after(nextMidnight(after: date))))
    }

    func entry(at date: Date) -> Entry {
        let day = localDate(date)
        let storage = currentStorage()
        let strengthStore = injectedStrengthStore ?? SharedStrengthStore(defaults: storage)
        let todayStore = injectedTodayStore ?? TodaySummaryStore(defaults: storage)
        let themeStore = injectedThemeStore ?? WidgetThemeStore(defaults: storage)
        return Entry(date: date, strength: strengthStore.read(), today: todayStore.read(forLocalDate: day), theme: themeStore.read(), isPlaceholder: false)
    }

    private func currentStorage() -> AppGroupDefaults {
        #if DEBUG && MAEUMJARO_QA_FIXTURES
        return DebugFixtureNamespace.active(in: appGroupDefaults)?.scopedDefaults(from: appGroupDefaults) ?? appGroupDefaults
        #else
        return appGroupDefaults
        #endif
    }

    private func localDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func nextMidnight(after date: Date) -> Date {
        calendar.nextDate(after: date, matching: DateComponents(hour: 0, minute: 0, second: 0), matchingPolicy: .nextTimePreservingSmallerComponents) ?? date.addingTimeInterval(86_400)
    }
}
