import Foundation
import SwiftData
import Testing

import MaeumjaroDomain
import MaeumjaroPersistence

@Test
@MainActor
func deletionCancelLeavesEventsSettingsAndPhrasesUntouched() async throws {
    let fixture = try await makeDeletionFixture()
    let beforeEvents = try await fixture.events.fetchAll()
    let beforeSettings = try await fixture.settings.load()
    let beforePhrases = try await fixture.phrases.fetchAll()
    _ = try fixture.service.requestConfirmation(for: .all)

    #expect(try await fixture.events.fetchAll() == beforeEvents)
    #expect(try await fixture.settings.load() == beforeSettings)
    #expect(try await fixture.phrases.fetchAll() == beforePhrases)
}

@Test
@MainActor
func deletionConfirmationRemovesSelectedOrAllEventsOnly() async throws {
    let fixture = try await makeDeletionFixture()
    let events = try await fixture.events.fetchAll()
    let selected = try fixture.service.requestConfirmation(for: .selected([events[0].id]))

    try fixture.service.confirm(selected)
    #expect(try await fixture.events.fetchAll().count == 1)
    #expect(try await fixture.settings.load() == .default)
    #expect(try await fixture.phrases.fetchAll().count == 1)

    let all = try fixture.service.requestConfirmation(for: .all)
    try fixture.service.confirm(all)
    #expect(try await fixture.events.fetchAll().isEmpty)
    #expect(try await fixture.settings.load() == .default)
    #expect(try await fixture.phrases.fetchAll().count == 1)
}

@Test
@MainActor
func deletionWithoutMatchingConfirmationTokenDoesNotChangeRows() async throws {
    let fixture = try await makeDeletionFixture()
    let before = try await fixture.events.fetchAll()
    let token = try fixture.service.requestConfirmation(for: .all)

    do {
        try fixture.service.delete(scope: .selected(Set(before.map(\.id))), confirmation: token)
        Issue.record("scope mismatch unexpectedly confirmed")
    } catch {
        guard let persistenceError = error as? PersistenceError else {
            Issue.record("unexpected deletion error: \(error)")
            return
        }
        #expect(persistenceError == .deletionConfirmationRequired)
    }
    #expect(try await fixture.events.fetchAll() == before)
}

private struct DeletionFixture {
    let container: ModelContainer
    let events: SwiftDataEventRepository
    let settings: SwiftDataSettingsRepository
    let phrases: SwiftDataPhraseRepository
    let service: EventDeletionService
}

@MainActor
private func makeDeletionFixture() async throws -> DeletionFixture {
    let container = try ModelContainerFactory.makeInMemory()
    let events = SwiftDataEventRepository(container: container)
    let settings = SwiftDataSettingsRepository(container: container)
    let phrases = SwiftDataPhraseRepository(container: container)
    try await events.insert(makeEvent(
        id: UUID(uuidString: "E5BC2394-A32F-4686-83AC-C1A185C7AC01")!
    ))
    try await events.insert(makeEvent(
        id: UUID(uuidString: "E5BC2394-A32F-4686-83AC-C1A185C7AC02")!
    ))
    try phrases.seed([Phrase(
        phraseID: "phrase.test.deletion",
        category: .redirect,
        tone: .gentle,
        minimumIntensity: .one,
        maximumIntensity: .five,
        textKO: "다음 동작을 고릅니다."
    )])
    try await settings.save(.default)
    return DeletionFixture(
        container: container,
        events: events,
        settings: settings,
        phrases: phrases,
        service: EventDeletionService(repository: events)
    )
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
        phraseID: "phrase.test.deletion",
        animationDurationMilliseconds: 1800,
        interruptedCount: 0,
        appVersion: "1.0 (1)"
    )
}
