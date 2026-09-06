import Foundation
import MaeumjaroDomain
import MaeumjaroShared
import XCTest
@testable import Maeumjaro

@MainActor
final class EventCompletionCoordinatorTests: XCTestCase {
    func testInsertedCompletionProjectsSummaryAndAlreadyRecordedDoesNotReloadAgain() async throws {
        let repo = SpyEventRepository()
        let reload = SpyReloader()
        let stores = makeStores()
        let projection = WidgetProjectionCoordinator(
            eventRepository: repo,
            summaryStore: stores.summary,
            themeStore: stores.theme,
            strengthStore: stores.strength,
            reloader: reload,
            clock: FixedClock()
        )
        let coordinator = EventCompletionCoordinator(recorder: repo, projection: projection)
        let event = makeEvent()

        let first = try await coordinator.recordCompletionWithProjection(CompletionRecordingRequest(event: event))
        let second = try await coordinator.recordCompletionWithProjection(CompletionRecordingRequest(event: event))

        XCTAssertEqual(first.recording, .inserted)
        XCTAssertNil(first.projectionError)
        XCTAssertEqual(second.recording, .alreadyRecorded)
        XCTAssertNil(second.projectionError)
        XCTAssertEqual(repo.rows.count, 1)
        XCTAssertEqual(repo.recordCalls, 1)
        XCTAssertEqual(reload.count, 1)
        XCTAssertEqual(stores.summary.read(forLocalDate: "2026-09-05").count, 1)
        XCTAssertEqual(stores.summary.read(forLocalDate: "2026-09-05").sum, 3)
    }

    func testProjectionFailureKeepsDurableRowAndForegroundRepairUpdatesSnapshot() async throws {
        let repo = SpyEventRepository()
        let reload = SpyReloader()
        let stores = makeStores()
        stores.summaryStorage.failWrites = true
        let projection = WidgetProjectionCoordinator(
            eventRepository: repo,
            summaryStore: stores.summary,
            themeStore: stores.theme,
            strengthStore: stores.strength,
            reloader: reload,
            clock: FixedClock()
        )
        let coordinator = EventCompletionCoordinator(recorder: repo, projection: projection)
        let result = try await coordinator.recordCompletionWithProjection(
            CompletionRecordingRequest(event: makeEvent())
        )
        XCTAssertEqual(result.recording, .inserted)
        XCTAssertNotNil(result.projectionError)
        XCTAssertEqual(repo.rows.count, 1)
        XCTAssertEqual(reload.count, 0)

        stores.summaryStorage.failWrites = false
        try await coordinator.repairProjectionOnForeground()
        let repaired = stores.summary.read(forLocalDate: "2026-09-05")
        XCTAssertEqual(repaired.count, 1)
        XCTAssertEqual(repaired.sum, 3)
        XCTAssertEqual(reload.count, 1)
    }
}

@MainActor
private final class SpyEventRepository: EventRepository, CompletionRecording {
    var rows: [UUID: InjectionEvent] = [:]
    var recordCalls = 0
    var failFetch = false

    func insert(_ event: InjectionEvent) async throws { rows[event.id] = event }
    func fetchAll() async throws -> [InjectionEvent] {
        if failFetch { throw TestError.failed }
        return Array(rows.values)
    }
    func fetch(id: UUID) async throws -> InjectionEvent? { rows[id] }
    func delete(id: UUID) async throws { rows.removeValue(forKey: id) }
    func deleteAll() async throws { rows.removeAll() }
    func recordCompletion(_ request: CompletionRecordingRequest) async throws -> CompletionRecordingOutcome {
        recordCalls += 1
        if rows[request.event.id] != nil { return .alreadyRecorded }
        rows[request.event.id] = request.event
        return .inserted
    }
}

private final class SpyReloader: WidgetTimelineReloader, @unchecked Sendable {
    private let lock = NSLock()
    private var reloadCount = 0
    var count: Int { lock.withLock { reloadCount } }
    func reloadTimelines(ofKind kind: String) {
        guard kind == AppIdentifiers.widgetKind else { return }
        lock.withLock { reloadCount += 1 }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock(); defer { unlock() }
        return body()
    }
}

private enum TestError: Error { case failed }

private struct FixedClock: Clock {
    let nowUTC = Date(timeIntervalSince1970: 1_788_566_400)
}

private func makeEvent() -> InjectionEvent {
    InjectionEvent(
        id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
        startedAtUTC: Date(timeIntervalSince1970: 1_757_000_000),
        completedAtUTC: Date(timeIntervalSince1970: 1_757_000_100),
        createdAtUTC: Date(timeIntervalSince1970: 1_757_000_100),
        eventLocalDate: "2026-09-05", timezoneOffsetMinutes: 540,
        intensity: .three, source: .app, phraseID: "test", animationDurationMilliseconds: 1800,
        interruptedCount: 0, appVersion: "test"
    )
}

private struct TestStores {
    let summaryStorage: MemoryDataStore
    let summary: TodaySummaryStore
    let theme: WidgetThemeStore
    let strength: SharedStrengthStore
}

private func makeStores() -> TestStores {
    let storage = MemoryDataStore()
    return TestStores(
        summaryStorage: storage,
        summary: TodaySummaryStore(storage: storage),
        theme: WidgetThemeStore(storage: storage),
        strength: SharedStrengthStore(storage: storage)
    )
}
