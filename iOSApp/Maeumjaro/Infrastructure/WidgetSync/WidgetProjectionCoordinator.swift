import Foundation
import MaeumjaroDomain
import MaeumjaroShared

enum WidgetProjectionError: Error, Equatable {
    case invalidToday
}

@MainActor
final class WidgetProjectionCoordinator {
    private let eventRepository: any EventRepository
    private let summaryStore: TodaySummaryStore
    private let themeStore: WidgetThemeStore
    private let strengthStore: SharedStrengthStore
    private let reloader: any WidgetTimelineReloader
    private let clock: any Clock
    private var reloadedForOperation = false

    init(
        eventRepository: any EventRepository,
        summaryStore: TodaySummaryStore,
        themeStore: WidgetThemeStore,
        strengthStore: SharedStrengthStore,
        reloader: any WidgetTimelineReloader = AppWidgetTimelineReloader(),
        clock: any Clock = SystemClock(),
        calendar: Calendar = .current
    ) {
        self.eventRepository = eventRepository
        self.summaryStore = summaryStore
        self.themeStore = themeStore
        self.strengthStore = strengthStore
        self.reloader = reloader
        self.clock = clock
        var configured = calendar
        configured.locale = Locale(identifier: "en_US_POSIX")
        self.calendar = configured
    }

    private let calendar: Calendar

    func projectTodaySummary() async throws -> TodaySummarySnapshot {
        reloadedForOperation = false
        let date = todayString()
        guard let window = HistoryWindow.free(today: date) else { throw WidgetProjectionError.invalidToday }
        let report = AnalyticsAggregator().aggregate(events: try await eventRepository.fetchAll(), period: window)
        let daily = report.daily[date] ?? DailyAnalytics(localDate: date, count: 0, intensitySum: 0)
        let snapshot = TodaySummarySnapshot(
            localDate: date,
            completionCount: daily.count,
            intensitySum: daily.intensitySum,
            writer: .app,
            updatedAt: clock.nowUTC,
            revision: 1
        )
        let stored = try summaryStore.write(snapshot)
        reloadOnce()
        return stored
    }

    func projectAfterCompletion() async throws -> TodaySummarySnapshot { try await projectTodaySummary() }
    func projectAfterDeletion() async throws -> TodaySummarySnapshot { try await projectTodaySummary() }

    func deleteEvent(id: UUID) async throws -> TodaySummarySnapshot {
        try await eventRepository.delete(id: id)
        return try await projectAfterDeletion()
    }

    func deleteAllEvents() async throws -> TodaySummarySnapshot {
        try await eventRepository.deleteAll()
        return try await projectAfterDeletion()
    }

    func strengthChanged(to intensity: Intensity) throws -> Intensity {
        reloadedForOperation = false
        let stored = try strengthStore.write(intensity, writer: .app, now: clock.nowUTC)
        reloadOnce()
        return stored
    }

    func themeChanged(to themeID: ThemeID) throws -> WidgetThemeSnapshot {
        reloadedForOperation = false
        let stored = try themeStore.write(themeID, writer: .app, now: clock.nowUTC)
        reloadOnce()
        return stored
    }

    /// Repairs the widget projection from durable app settings when the app returns
    /// to the foreground. The settings repository is the authority; the widget
    /// snapshot is only read back to avoid an unnecessary write/reload.
    @discardableResult
    func reconcileWidgetTheme(from settings: AppSettings) throws -> WidgetThemeSnapshot? {
        guard themeStore.readSnapshot()?.themeID != settings.themeID else { return nil }
        reloadedForOperation = false
        let stored = try themeStore.write(settings.themeID, writer: .app, now: clock.nowUTC)
        reloadOnce()
        return stored
    }

    func entitlementDowngraded() throws -> WidgetThemeSnapshot {
        try themeChanged(to: .default)
    }

    func resetOperationReloadGuard() { reloadedForOperation = false }

    private func reloadOnce() {
        guard !reloadedForOperation else { return }
        reloadedForOperation = true
        reloader.reloadTimelines(ofKind: AppIdentifiers.widgetKind)
    }

    private func todayString() -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: clock.nowUTC)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
