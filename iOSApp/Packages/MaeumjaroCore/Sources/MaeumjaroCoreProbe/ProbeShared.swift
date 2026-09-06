import CryptoKit
import Foundation

import MaeumjaroDomain
import MaeumjaroShared

func runSharedProbe(_ arguments: ProbeArguments) throws -> ProbeResponse {
    let suite = arguments.value(for: "suite") ?? "task7-default"
    guard isValidSuite(suite) else {
        throw ProbeCommandError.invalidArguments(command: "shared", detail: "invalid-suite")
    }

    let directory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        .appendingPathComponent(".omo/evidence/maeumjaro-ios-implementation/task-7/probe-stores", isDirectory: true)
        .appendingPathComponent(suite, isDirectory: true)
    let storage = try FileDataStore(directoryURL: directory)
    let defaults = AppGroupDefaults(storage: storage)

    if let fixture = arguments.value(for: "fixture") {
        return try runSharedFixture(fixture, defaults: defaults, suite: suite, directory: directory)
    }

    let writes = try parseWrites(arguments.value(for: "writes") ?? "")
    for (index, write) in writes.enumerated() {
        guard let intensity = Intensity(rawValue: write.intensity) else {
            throw ProbeCommandError.invalidArguments(command: "shared", detail: "invalid-intensity")
        }
        _ = try SharedStrengthStore(defaults: defaults).write(
            intensity,
            writer: write.writer,
            now: Date(timeIntervalSince1970: TimeInterval(index + 1))
        )
    }

    let appStore = SharedStrengthStore(defaults: defaults)
    let widgetStore = SharedStrengthStore(defaults: defaults)
    let envelope = appStore.readEnvelope()
    var data: [String: ProbeJSONValue] = [
        "adapter": .string("FileDataStore"),
        "logicalSuite": .string(suite),
        "storagePath": .string(directory.path),
        "appRead": .integer(appStore.read().rawValue),
        "widgetRead": .integer(widgetStore.read().rawValue),
        "revision": .integer(envelope?.revision ?? 0),
        "writer": envelope.map { .string($0.writer.rawValue) } ?? .null
    ]
    if let requestedReads = arguments.value(for: "read") {
        let readers = requestedReads.split(separator: ",", omittingEmptySubsequences: true).map(String.init)
        data["readers"] = .array(readers.map(ProbeJSONValue.string))
    }
    return ProbeResponse(command: "shared", status: "ok", data: data)
}

private struct SharedWrite {
    let writer: SharedSnapshotWriter
    let intensity: Int
}

private func parseWrites(_ value: String) throws -> [SharedWrite] {
    guard !value.isEmpty else {
        throw ProbeCommandError.invalidArguments(command: "shared", detail: "missing-writes")
    }
    return try value.split(separator: ",", omittingEmptySubsequences: true).map { token in
        let pieces = token.split(separator: ":", omittingEmptySubsequences: false)
        guard pieces.count == 2,
              let writer = SharedSnapshotWriter(rawValue: String(pieces[0])),
              writer == .app || writer == .intent,
              let intensity = Int(pieces[1]) else {
            throw ProbeCommandError.invalidArguments(command: "shared", detail: "invalid-writes")
        }
        return SharedWrite(writer: writer, intensity: intensity)
    }
}

private func runSharedFixture(
    _ fixture: String,
    defaults: AppGroupDefaults,
    suite: String,
    directory: URL
) throws -> ProbeResponse {
    guard fixture == "corrupt-v2" else {
        throw ProbeCommandError.invalidArguments(command: "shared", detail: "unknown-fixture")
    }

    let strength = Data(#"{"schemaVersion":2,"updatedAt":0,"writer":"app","revision":8,"intensity":5}"#.utf8)
    let summary = Data("not-json".utf8)
    let theme = Data(#"{"schemaVersion":2,"updatedAt":0,"writer":"app","revision":8,"themeID":"midnightInk"}"#.utf8)
    try defaults.set(strength, forKey: AppGroupDefaults.Keys.strength)
    try defaults.set(summary, forKey: AppGroupDefaults.Keys.todaySummary)
    try defaults.set(theme, forKey: AppGroupDefaults.Keys.widgetTheme)

    let before = snapshotHashes(from: defaults)
    let strengthValue = SharedStrengthStore(defaults: defaults).read()
    let today = TodaySummaryStore(defaults: defaults).read(forLocalDate: "2026-09-05")
    let themeValue = WidgetThemeStore(defaults: defaults).read()
    let after = snapshotHashes(from: defaults)

    return ProbeResponse(
        command: "shared",
        status: "ok",
        data: [
            "adapter": .string("FileDataStore"),
            "logicalSuite": .string(suite),
            "storagePath": .string(directory.path),
            "strengthFallback": .integer(strengthValue.rawValue),
            "todayCount": .integer(today.completionCount),
            "todaySum": .integer(today.intensitySum),
            "themeFallback": .string(themeValue.rawValue),
            "strengthHashBefore": jsonHash(before.strength),
            "strengthHashAfter": jsonHash(after.strength),
            "todayHashBefore": jsonHash(before.today),
            "todayHashAfter": jsonHash(after.today),
            "themeHashBefore": jsonHash(before.theme),
            "themeHashAfter": jsonHash(after.theme),
            "sourceBytesPreserved": .boolean(before == after),
            "eventFieldsPresent": .boolean(false)
        ]
    )
}

private struct SnapshotHashes: Equatable {
    let strength: String?
    let today: String?
    let theme: String?
}

private func snapshotHashes(from defaults: AppGroupDefaults) -> SnapshotHashes {
    SnapshotHashes(
        strength: digest(defaults.data(forKey: AppGroupDefaults.Keys.strength)),
        today: digest(defaults.data(forKey: AppGroupDefaults.Keys.todaySummary)),
        theme: digest(defaults.data(forKey: AppGroupDefaults.Keys.widgetTheme))
    )
}

private func digest(_ data: Data?) -> String? {
    guard let data else { return nil }
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}

private func jsonHash(_ value: String?) -> ProbeJSONValue {
    value.map(ProbeJSONValue.string) ?? .null
}

private func isValidSuite(_ suite: String) -> Bool {
    !suite.isEmpty && suite.allSatisfy { $0.isLetter || $0.isNumber || $0 == "." || $0 == "-" || $0 == "_" }
}
