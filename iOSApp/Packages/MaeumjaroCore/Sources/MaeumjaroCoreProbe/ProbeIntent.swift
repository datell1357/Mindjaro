import Foundation
import MaeumjaroDomain
import MaeumjaroIntents

@MainActor
func runIntentProbe(_ arguments: ProbeArguments) async throws -> ProbeResponse {
    let supportedOptions: Set<String> = ["current", "delta", "target", "revision", "fixture"]
    guard Set(arguments.options.keys).isSubset(of: supportedOptions) else {
        throw ProbeCommandError.invalidArguments(command: "intent", detail: "unsupported-option")
    }

    let fixture = arguments.value(for: "fixture")
    guard fixture == nil || fixture == "corrupt" else {
        throw ProbeCommandError.invalidArguments(command: "intent", detail: "unknown-fixture")
    }

    let initialRawValue: Int
    if fixture == "corrupt" {
        initialRawValue = Intensity.default.rawValue
    } else {
        guard let rawValue = Int(arguments.value(for: "current") ?? "3") else {
            throw ProbeCommandError.invalidArguments(command: "intent", detail: "invalid-current")
        }
        initialRawValue = rawValue
    }
    guard let initialIntensity = Intensity(rawValue: initialRawValue) else {
        throw ProbeCommandError.invalidArguments(command: "intent", detail: "invalid-current")
    }

    let initialRevision: Int
    if let revisionValue = arguments.value(for: "revision") {
        guard let revision = Int(revisionValue), revision >= 0 else {
            throw ProbeCommandError.invalidArguments(command: "intent", detail: "invalid-revision")
        }
        initialRevision = revision
    } else {
        initialRevision = 0
    }

    let target = try parseOptionalInt(arguments.value(for: "target"), option: "target")
    let delta = try parseOptionalInt(arguments.value(for: "delta"), option: "delta")
    let store = ProbeStrengthStore(
        intensity: initialIntensity,
        revision: initialRevision,
        shouldFailPersist: arguments.hasFlag("fail-write")
    )
    let intent = SetStrengthIntent(
        target: target,
        delta: delta,
        dependencies: IntentDependencies(store: store)
    )

    do {
        let result = try await intent.perform()
        let returned = result.value ?? initialIntensity.rawValue
        return ProbeResponse(
            command: "intent",
            status: "ok",
            data: probeData(
                store: store,
                initialIntensity: initialIntensity,
                initialRevision: initialRevision,
                returned: returned,
                fixture: fixture,
                trace: arguments.hasFlag("trace"),
                outcome: "success"
            )
        )
    } catch let error as SetStrengthIntentError {
        return ProbeResponse(
            command: "intent",
            status: "error",
            data: probeData(
                store: store,
                initialIntensity: initialIntensity,
                initialRevision: initialRevision,
                returned: nil,
                fixture: fixture,
                trace: arguments.hasFlag("trace"),
                outcome: errorCode(error)
            )
        )
    }
}

private final class ProbeStrengthStore: StrengthIntentStore, @unchecked Sendable {
    private let lock = NSLock()
    private var intensity: Intensity
    private var storedRevision: Int
    private let shouldFailPersist: Bool
    private var recordedOperations: [String] = []

    init(intensity: Intensity, revision: Int, shouldFailPersist: Bool) {
        self.intensity = intensity
        storedRevision = revision
        self.shouldFailPersist = shouldFailPersist
    }

    func read() async -> Intensity {
        lock.withLock { intensity }
    }

    func persist(_ intensity: Intensity) async throws {
        try lock.withLock {
            recordedOperations.append("persist(\(intensity.rawValue))")
            guard !shouldFailPersist else { throw ProbeStoreError.writeRejected }
            self.intensity = intensity
            storedRevision += 1
        }
    }

    func readBack() async throws -> Intensity {
        lock.withLock {
            recordedOperations.append("readBack(\(intensity.rawValue))")
            return intensity
        }
    }

    func snapshot() -> (intensity: Intensity, revision: Int, operations: [String]) {
        lock.withLock { (intensity, storedRevision, recordedOperations) }
    }

    private enum ProbeStoreError: Error {
        case writeRejected
    }
}

private func parseOptionalInt(_ value: String?, option: String) throws -> Int? {
    guard let value else { return nil }
    guard let parsed = Int(value) else {
        throw ProbeCommandError.invalidArguments(command: "intent", detail: "invalid-\(option)")
    }
    return parsed
}

private func probeData(
    store: ProbeStrengthStore,
    initialIntensity: Intensity,
    initialRevision: Int,
    returned: Int?,
    fixture: String?,
    trace: Bool,
    outcome: String
) -> [String: ProbeJSONValue] {
    let snapshot = store.snapshot()
    var data: [String: ProbeJSONValue] = [
        "initial": .integer(initialIntensity.rawValue),
        "current": .integer(snapshot.intensity.rawValue),
        "revision": .integer(snapshot.revision),
        "initialRevision": .integer(initialRevision),
        "outcome": .string(outcome),
        "fixture": fixture.map(ProbeJSONValue.string) ?? .null
    ]
    if let returned {
        data["returned"] = .integer(returned)
    }
    if trace {
        var operations = snapshot.operations
        operations.append("return(\(outcome))")
        data["trace"] = .array(operations.map(ProbeJSONValue.string))
    }
    if fixture == "corrupt" {
        data["corruptFallback"] = .boolean(true)
    }
    return data
}

private func errorCode(_ error: SetStrengthIntentError) -> String {
    switch error {
    case .invalidParameters:
        "invalid-parameters"
    case .invalidTarget:
        "invalid-target"
    case .invalidDelta:
        "invalid-delta"
    case .dependencyUnavailable:
        "dependency-unavailable"
    case .persistFailed:
        "persist-failed"
    case .readBackFailed:
        "read-back-failed"
    }
}
