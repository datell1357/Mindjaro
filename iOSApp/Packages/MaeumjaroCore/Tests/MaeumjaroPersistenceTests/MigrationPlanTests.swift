import Foundation
import Testing

import MaeumjaroDomain
import MaeumjaroPersistence

@Test
@MainActor
func v1StoreReopensWithItsRowsAndSchemaVersion() async throws {
    let root = ProcessInfo.processInfo.environment["MAEUMJARO_TASK6_EVIDENCE"]
        .map(URL.init(fileURLWithPath:))
        ?? FileManager.default.temporaryDirectory.appendingPathComponent("maeumjaro-task6", isDirectory: true)
    let storeURL = root
        .appendingPathComponent("migration-fixture-\(UUID().uuidString)", isDirectory: true)
        .appendingPathComponent("store.sqlite", isDirectory: false)
    let event = InjectionEvent(
        id: UUID(uuidString: "0F5C9D92-4540-435F-8D9C-CE299D1B132C")!,
        startedAtUTC: Date(timeIntervalSince1970: 1_757_000_000),
        completedAtUTC: Date(timeIntervalSince1970: 1_757_000_002),
        createdAtUTC: Date(timeIntervalSince1970: 1_757_000_002),
        eventLocalDate: "2026-09-05",
        timezoneOffsetMinutes: 540,
        intensity: .five,
        source: .widget,
        phraseID: "phrase.autonomy.neutral.001",
        animationDurationMilliseconds: 3200,
        interruptedCount: 1,
        appVersion: "1.0 (1)"
    )

    do {
        let first = try ModelContainerFactory.makePersistent(at: storeURL)
        try await SwiftDataEventRepository(container: first).insert(event)
    }
    let reopened = try ModelContainerFactory.open(at: storeURL)

    #expect(reopened.schema.version == MaeumjaroSchemaV1.versionIdentifier)
    #expect(try await SwiftDataEventRepository(container: reopened).fetch(id: event.id) == event)
}

@Test
@MainActor
func migrationFailureDoesNotRemoveAnExistingUnsupportedFile() throws {
    let root = ProcessInfo.processInfo.environment["MAEUMJARO_TASK6_EVIDENCE"]
        .map(URL.init(fileURLWithPath:))
        ?? FileManager.default.temporaryDirectory.appendingPathComponent("maeumjaro-task6", isDirectory: true)
    let directory = root.appendingPathComponent("unsupported-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let storeURL = directory.appendingPathComponent("store.sqlite", isDirectory: false)
    let marker = Data("unsupported-store-marker".utf8)
    try marker.write(to: storeURL)

    do {
        _ = try ModelContainerFactory.open(at: storeURL)
        Issue.record("opening an unsupported store unexpectedly succeeded")
    } catch {
        #expect(error is PersistenceError)
        #expect(try Data(contentsOf: storeURL) == marker)
    }
}
