import Foundation
import MaeumjaroDomain
import MaeumjaroShared
import XCTest
@testable import Maeumjaro

@MainActor
final class WidgetProjectionCoordinatorTests: XCTestCase {
    func testDeleteAndThemeOperationsProjectReadBackAndReloadOnce() async throws {
        let event = InjectionEvent(
            id: UUID(), startedAtUTC: Date(), completedAtUTC: Date(), createdAtUTC: Date(),
            eventLocalDate: "2026-09-05", timezoneOffsetMinutes: 540, intensity: .five,
            source: .app, phraseID: "test", animationDurationMilliseconds: 1000,
            interruptedCount: 0, appVersion: "test"
        )
        let repo = ProjectionTestRepository(event: event)
        let storage = MemoryDataStore()
        let reload = ProjectionTestReloader()
        let coordinator = WidgetProjectionCoordinator(
            eventRepository: repo,
            summaryStore: TodaySummaryStore(storage: storage),
            themeStore: WidgetThemeStore(storage: storage),
            strengthStore: SharedStrengthStore(storage: storage),
            reloader: reload,
            clock: ProjectionFixedClock()
        )

        let initial = try await coordinator.projectTodaySummary()
        XCTAssertEqual(initial.count, 1)
        XCTAssertEqual(initial.sum, 5)
        XCTAssertEqual(reload.count, 1)

        let deleted = try await coordinator.deleteEvent(id: event.id)
        XCTAssertEqual(deleted.count, 0)
        XCTAssertEqual(deleted.sum, 0)
        XCTAssertEqual(reload.count, 2)

        let theme = try coordinator.themeChanged(to: .midnightInk)
        XCTAssertEqual(theme.themeID, .midnightInk)
        XCTAssertEqual(WidgetThemeStore(storage: storage).read(), .midnightInk)
        XCTAssertEqual(reload.count, 3)
    }

    func testThemeReconciliationRetriesAfterWriteFailureAndSkipsUnchangedSnapshot() throws {
        let storage = MemoryDataStore()
        let themeStore = WidgetThemeStore(storage: storage)
        let clock = ProjectionFixedClock()
        _ = try themeStore.write(.midnightInk, writer: .app, now: clock.nowUTC)
        storage.failWrites = true
        let reload = ProjectionTestReloader()
        let coordinator = WidgetProjectionCoordinator(
            eventRepository: ProjectionTestRepository(event: nil),
            summaryStore: TodaySummaryStore(storage: storage),
            themeStore: themeStore,
            strengthStore: SharedStrengthStore(storage: storage),
            reloader: reload,
            clock: clock
        )

        XCTAssertThrowsError(try coordinator.reconcileWidgetTheme(from: AppSettings(themeID: .quietIvory)))
        XCTAssertEqual(themeStore.readSnapshot()?.themeID, .midnightInk)
        XCTAssertEqual(reload.count, 0)

        storage.failWrites = false
        let repaired = try coordinator.reconcileWidgetTheme(from: AppSettings(themeID: .quietIvory))
        XCTAssertEqual(repaired?.themeID, .quietIvory)
        XCTAssertEqual(themeStore.readSnapshot()?.themeID, .quietIvory)
        XCTAssertEqual(reload.count, 1)

        XCTAssertNil(try coordinator.reconcileWidgetTheme(from: AppSettings(themeID: .quietIvory)))
        XCTAssertEqual(reload.count, 1)
    }
}

@MainActor private final class ProjectionTestRepository: EventRepository {
    var event: InjectionEvent?
    init(event: InjectionEvent?) { self.event = event }
    func insert(_ event: InjectionEvent) async throws { self.event = event }
    func fetchAll() async throws -> [InjectionEvent] { event.map { [$0] } ?? [] }
    func fetch(id: UUID) async throws -> InjectionEvent? { event?.id == id ? event : nil }
    func delete(id: UUID) async throws { if event?.id == id { event = nil } }
    func deleteAll() async throws { event = nil }
}

private final class ProjectionTestReloader: WidgetTimelineReloader, @unchecked Sendable {
    private let lock = NSLock()
    private var reloadCount = 0
    var count: Int { lock.withLock { reloadCount } }
    func reloadTimelines(ofKind kind: String) { lock.withLock { reloadCount += 1 } }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock(); defer { unlock() }
        return body()
    }
}

private struct ProjectionFixedClock: Clock {
    let nowUTC = Date(timeIntervalSince1970: 1_788_566_400)
}
