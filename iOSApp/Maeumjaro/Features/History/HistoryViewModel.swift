import Foundation
import MaeumjaroDomain
import Observation

@MainActor
@Observable
final class HistoryViewModel {
    private let eventRepository: any EventRepository
    private let clock: any Clock
    private let calendarProvider: any CalendarProviding
    private let aggregator: AnalyticsAggregator
    private(set) var policy: FeatureAccessPolicy
    private let onEventsDeleted: @MainActor () async -> Void

    private(set) var report: AnalyticsReport?
    private(set) var events: [InjectionEvent] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var selectedDate: String?
    var metric: HeatmapMetric = .count

    init(eventRepository: any EventRepository, clock: any Clock = SystemClock(), calendar: any CalendarProviding = SystemCalendarProvider(), entitlement: Entitlement = .free, aggregator: AnalyticsAggregator = .init(), onEventsDeleted: @escaping @MainActor () async -> Void = {}) {
        self.eventRepository = eventRepository
        self.clock = clock
        self.calendarProvider = calendar
        self.policy = FeatureAccessPolicy(entitlement: entitlement)
        self.aggregator = aggregator
        self.onEventsDeleted = onEventsDeleted
    }

    func updateEntitlement(_ entitlement: Entitlement) { policy = FeatureAccessPolicy(entitlement: entitlement) }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await eventRepository.fetchAll()
            events = loaded.sorted { $0.completedAtUTC > $1.completedAtUTC }
            let today = Self.dateString(clock.nowUTC, calendar: calendarProvider.calendar)
            guard let window = policy.historyWindow(today: today) else { report = nil; return }
            report = aggregator.aggregate(events: loaded, period: window)
            errorMessage = nil
        } catch {
            errorMessage = String(localized: "기록을 불러오지 못했어요. 다시 시도해 주세요.")
        }
    }

    func delete(id: UUID) async {
        do {
            try await eventRepository.delete(id: id)
            await load()
            await onEventsDeleted()
        } catch {
            errorMessage = String(localized: "기록을 삭제하지 못했어요. 다시 시도해 주세요.")
        }
    }

    var recentEvents: [InjectionEvent] { Array(events.filter { report?.period.contains($0.eventLocalDate) == true }.prefix(10)) }
    var accessibilityContent: HistoryAccessibilityContent { report.map { .make(report: $0, selectedDate: selectedDate) } ?? .init(summary: [], dates: [], heatmap: [], charts: [], detail: []) }

    private static func dateString(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter(); formatter.calendar = calendar; formatter.timeZone = calendar.timeZone; formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd"; return formatter.string(from: date)
    }
}
