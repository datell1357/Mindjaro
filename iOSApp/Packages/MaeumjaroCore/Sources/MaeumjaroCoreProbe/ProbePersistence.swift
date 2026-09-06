import CryptoKit
import Foundation

import MaeumjaroDomain
import MaeumjaroPersistence

@MainActor
func runPersistenceProbe(_ arguments: ProbeArguments) async throws -> ProbeResponse {
    let supportedOptions = Set(["store", "scenario"])
    guard Set(arguments.options.keys).isSubset(of: supportedOptions), arguments.flags.isEmpty else {
        throw ProbeCommandError.invalidArguments(command: "persistence", detail: "unsupported-option")
    }
    guard let storePath = arguments.value(for: "store"), !storePath.isEmpty else {
        throw ProbeCommandError.invalidArguments(command: "persistence", detail: "missing-store")
    }
    guard let scenario = arguments.value(for: "scenario"), !scenario.isEmpty else {
        throw ProbeCommandError.invalidArguments(command: "persistence", detail: "missing-scenario")
    }

    let storeURL = URL(fileURLWithPath: storePath)
    guard storeURL.isFileURL, storeURL.path.hasPrefix("/") else {
        throw ProbeCommandError.invalidArguments(command: "persistence", detail: "store-must-be-absolute")
    }

    switch scenario {
    case "complete-twice":
        return try await runCompletionProbe(storeURL: storeURL)
    case "unsupported-migration", "unsupported-migration-fixture-preserved",
         "unsupportedmigrationfixturepreserved":
        return try runUnsupportedMigrationProbe(storeURL: storeURL)
    default:
        throw ProbeCommandError.invalidArguments(command: "persistence", detail: "unknown-scenario")
    }
}

@MainActor
private func runCompletionProbe(storeURL: URL) async throws -> ProbeResponse {
    let container = try ModelContainerFactory.makePersistent(at: storeURL)
    let repository = SwiftDataEventRepository(container: container)
    let event = InjectionEvent(
        id: UUID(uuidString: "A9A4B7C2-DB8E-4A01-8E9D-7DDF4AB0C5E1")!,
        startedAtUTC: Date(timeIntervalSince1970: 1_757_000_000),
        completedAtUTC: Date(timeIntervalSince1970: 1_757_000_001.8),
        createdAtUTC: Date(timeIntervalSince1970: 1_757_000_001.8),
        eventLocalDate: "2026-09-05",
        timezoneOffsetMinutes: 540,
        intensity: .three,
        source: .app,
        phraseID: "phrase.autonomy.neutral.001",
        animationDurationMilliseconds: 1800,
        interruptedCount: 0,
        appVersion: "1.0 (1)"
    )
    let request = CompletionRecordingRequest(event: event)
    let firstOutcome = try await repository.recordCompletion(request)
    let secondOutcome = try await repository.recordCompletion(request)
    let rows = try await repository.fetchAll()

    return ProbeResponse(
        command: "persistence",
        status: "ok",
        data: [
            "scenario": .string("complete-twice"),
            "storePath": .string(storeURL.path),
            "firstOutcome": .string(firstOutcome.rawValue),
            "secondOutcome": .string(secondOutcome.rawValue),
            "outcomes": .array([
                .string(firstOutcome.rawValue),
                .string(secondOutcome.rawValue)
            ]),
            "rowCount": .integer(rows.count),
            "rows": .array(rows.map(rowValue))
        ]
    )
}

private func rowValue(_ event: InjectionEvent) -> ProbeJSONValue {
    .object([
        "id": .string(event.id.uuidString),
        "startedAtUTC": .double(event.startedAtUTC.timeIntervalSince1970),
        "completedAtUTC": .double(event.completedAtUTC.timeIntervalSince1970),
        "createdAtUTC": .double(event.createdAtUTC.timeIntervalSince1970),
        "eventLocalDate": .string(event.eventLocalDate),
        "timezoneOffsetMinutes": .integer(event.timezoneOffsetMinutes),
        "intensity": .integer(event.intensity.rawValue),
        "source": .string(event.source.rawValue),
        "phraseID": .string(event.phraseID),
        "animationDurationMilliseconds": .integer(event.animationDurationMilliseconds),
        "interruptedCount": .integer(event.interruptedCount),
        "appVersion": .string(event.appVersion)
    ])
}

@MainActor
private func runUnsupportedMigrationProbe(storeURL: URL) throws -> ProbeResponse {
    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: storeURL.path) {
        try fileManager.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("unsupported-schema-fixture".utf8).write(to: storeURL, options: .atomic)
    }
    let before = try Data(contentsOf: storeURL)
    let beforeHash = sha256Hex(before)

    do {
        _ = try ModelContainerFactory.open(at: storeURL)
    } catch let error as PersistenceError {
        guard case .migrationUnsupported = error else {
            throw ProbeCommandError.invalidArguments(command: "persistence", detail: "unexpected-migration-error")
        }
        let after = try Data(contentsOf: storeURL)
        let afterHash = sha256Hex(after)
        guard beforeHash == afterHash else {
            throw ProbeCommandError.invalidArguments(command: "persistence", detail: "migration-source-changed")
        }
        throw ProbeCommandError.invalidArguments(command: "persistence", detail: "migration-unsupported")
    }

    throw ProbeCommandError.invalidArguments(command: "persistence", detail: "migration-unsupported-not-raised")
}

private func sha256Hex(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}
