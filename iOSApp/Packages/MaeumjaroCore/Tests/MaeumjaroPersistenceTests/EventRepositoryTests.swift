import Foundation
import Testing

import MaeumjaroDomain
import MaeumjaroPersistence

@Test
@MainActor
func eventRepositoryRoundTripsCompletedEventsAndKeepsIncompleteAtZero() async throws {
    let container = try ModelContainerFactory.makeInMemory()
    let repository = SwiftDataEventRepository(container: container)
    let event = makeEvent(id: UUID(uuidString: "C39D6CE4-0FC7-4ED6-9EB6-4A4B3DAD7C2B")!)

    try await repository.insert(event)

    #expect(try await repository.fetchAll() == [event])
    #expect(try await repository.fetch(id: event.id) == event)
}

@Test
@MainActor
func eventRepositoryMakesRepeatedCompletionInsertIdempotent() async throws {
    let container = try ModelContainerFactory.makeInMemory()
    let repository = SwiftDataEventRepository(container: container)
    let event = makeEvent(id: UUID(uuidString: "D6BE7E97-B8A8-43BA-884D-9FEA0A6F643C")!)
    let request = CompletionRecordingRequest(event: event)

    #expect(try await repository.recordCompletion(request) == .inserted)
    #expect(try await repository.recordCompletion(request) == .alreadyRecorded)
    #expect(try await repository.fetchAll().count == 1)
}

@Test
@MainActor
func eventRepositoryKeepsOneRowForConcurrentDuplicateUUIDInserts() async throws {
    let container = try ModelContainerFactory.makeInMemory()
    let repository = SwiftDataEventRepository(container: container)
    let event = makeEvent(id: UUID(uuidString: "4F4FD7B1-A0F5-4D41-B1E7-15A7DA055F2E")!)

    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<8 {
            group.addTask {
                try? await repository.insert(event)
            }
        }
        await group.waitForAll()
    }

    #expect(try await repository.fetchAll() == [event])
}

@Test
@MainActor
func eventRepositoryDeletesOnlyTheRequestedEvent() async throws {
    let container = try ModelContainerFactory.makeInMemory()
    let repository = SwiftDataEventRepository(container: container)
    let first = makeEvent(id: UUID(uuidString: "8E294D58-DA0C-43EA-914E-8C0B4AE70001")!)
    let second = makeEvent(id: UUID(uuidString: "8E294D58-DA0C-43EA-914E-8C0B4AE70002")!)
    try await repository.insert(first)
    try await repository.insert(second)

    try await repository.delete(id: first.id)

    #expect(try await repository.fetchAll() == [second])
}

private func makeEvent(id: UUID) -> InjectionEvent {
    let start = Date(timeIntervalSince1970: 1_757_000_000)
    return InjectionEvent(
        id: id,
        startedAtUTC: start,
        completedAtUTC: start.addingTimeInterval(1.8),
        createdAtUTC: start.addingTimeInterval(1.8),
        eventLocalDate: "2026-09-05",
        timezoneOffsetMinutes: 540,
        intensity: .three,
        source: .app,
        phraseID: "phrase.autonomy.neutral.001",
        animationDurationMilliseconds: 1800,
        interruptedCount: 0,
        appVersion: "1.0 (1)"
    )
}
