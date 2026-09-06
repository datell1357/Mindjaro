import Foundation
import Testing

import MaeumjaroDomain
import MaeumjaroIntents
import MaeumjaroShared

private final class TraceStrengthStore: StrengthIntentStore, @unchecked Sendable {
    private let lock = NSLock()
    private var intensity: Intensity
    private var storedRevision: Int
    private let shouldFailPersist: Bool
    private let readBackValue: Intensity?
    private(set) var operations: [String] = []

    init(
        intensity: Intensity,
        revision: Int = 0,
        shouldFailPersist: Bool = false,
        readBackValue: Intensity? = nil
    ) {
        self.intensity = intensity
        storedRevision = revision
        self.shouldFailPersist = shouldFailPersist
        self.readBackValue = readBackValue
    }

    func read() async -> Intensity {
        lock.withLock { intensity }
    }

    func persist(_ intensity: Intensity) async throws {
        try lock.withLock {
            operations.append("persist(\(intensity.rawValue))")
            guard !shouldFailPersist else { throw TestStoreError.persistRejected }
            self.intensity = intensity
            storedRevision += 1
        }
    }

    func readBack() async throws -> Intensity {
        lock.withLock {
            let value = readBackValue ?? intensity
            operations.append("readBack(\(value.rawValue))")
            return value
        }
    }

    var revision: Int {
        lock.withLock { storedRevision }
    }

    private enum TestStoreError: Error {
        case persistRejected
    }
}

@Test
func targetStrengthPersistsThenReadsBackWithoutOpeningTheApp() async throws {
    let store = TraceStrengthStore(intensity: .three)
    let intent = SetStrengthIntent(
        target: 5,
        dependencies: IntentDependencies(store: store)
    )

    let result = try await intent.perform()

    #expect(result.value == 5)
    #expect(store.operations == ["persist(5)", "readBack(5)"])
    #expect(store.revision == 1)
    #expect(SetStrengthIntent.openAppWhenRun == false)
}

@Test(arguments: [
    (Intensity.one, -1),
    (Intensity.five, 1)
])
func boundaryDeltaIsANoopAndPreservesRevision(
    current: Intensity,
    delta: Int
) async throws {
    let store = TraceStrengthStore(intensity: current, revision: 7)
    let intent = SetStrengthIntent(
        delta: delta,
        dependencies: IntentDependencies(store: store)
    )

    let result = try await intent.perform()

    #expect(result.value == current.rawValue)
    #expect(store.operations.isEmpty)
    #expect(store.revision == 7)
}

@Test(arguments: [1, 2, 3, 4, 5])
func directTargetsInTheSupportedRangeAreAccepted(_ target: Int) async throws {
    let store = TraceStrengthStore(intensity: .three)
    let intent = SetStrengthIntent(
        target: target,
        dependencies: IntentDependencies(store: store)
    )

    let result = try await intent.perform()

    #expect(result.value == target)
}

@Test(arguments: [0, 6])
func directTargetsOutsideTheSupportedRangeFail(_ target: Int) async {
    let intent = SetStrengthIntent(
        target: target,
        dependencies: IntentDependencies(store: TraceStrengthStore(intensity: .three))
    )

    do {
        _ = try await intent.perform()
        #expect(Bool(false), "an out-of-range direct target must fail")
    } catch let error as SetStrengthIntentError {
        #expect(error == .invalidTarget(target))
    } catch {
        #expect(Bool(false), "the intent must expose a typed validation error")
    }
}

@Test(arguments: [0, -2, 2])
func unsupportedDeltasFailWithoutPersisting(_ delta: Int) async {
    let store = TraceStrengthStore(intensity: .three)
    let intent = SetStrengthIntent(
        delta: delta,
        dependencies: IntentDependencies(store: store)
    )

    do {
        _ = try await intent.perform()
        #expect(Bool(false), "only a single step delta is supported")
    } catch let error as SetStrengthIntentError {
        #expect(error == .invalidDelta(delta))
        #expect(store.operations.isEmpty)
    } catch {
        #expect(Bool(false), "the intent must expose a typed validation error")
    }
}

@Test
func missingOrAmbiguousParametersFailExplicitly() async {
    let dependencies = IntentDependencies(
        store: TraceStrengthStore(intensity: .three)
    )

    for intent in [
        SetStrengthIntent(dependencies: dependencies),
        SetStrengthIntent(target: 4, delta: 1, dependencies: dependencies)
    ] {
        do {
            _ = try await intent.perform()
            #expect(Bool(false), "the intent must require exactly one operation")
        } catch let error as SetStrengthIntentError {
            #expect(error == .invalidParameters)
        } catch {
            #expect(Bool(false), "the intent must expose a typed validation error")
        }
    }
}

@Test
func corruptSharedStrengthFallsBackToThreeBeforeApplyingDelta() async throws {
    let storage = MemoryDataStore()
    let defaults = AppGroupDefaults(storage: storage)
    try defaults.set(Data("not-json".utf8), forKey: AppGroupDefaults.Keys.strength)
    let intent = SetStrengthIntent(
        delta: 1,
        dependencies: IntentDependencies(
            sharedStrengthStore: SharedStrengthStore(defaults: defaults)
        )
    )

    let result = try await intent.perform()

    #expect(result.value == 4)
    #expect(SharedStrengthStore(defaults: defaults).read() == .four)
}

@Test
func failedPersistExposesPreviousIntensityAndPreservesStoredData() async {
    let store = TraceStrengthStore(
        intensity: .four,
        revision: 9,
        shouldFailPersist: true
    )
    let intent = SetStrengthIntent(
        delta: 1,
        dependencies: IntentDependencies(store: store)
    )

    do {
        _ = try await intent.perform()
        #expect(Bool(false), "a failed write must not be reported as success")
    } catch let error as SetStrengthIntentError {
        #expect(error == .persistFailed(previousIntensity: .four))
        #expect(store.revision == 9)
        #expect(await store.read() == .four)
        #expect(store.operations == ["persist(5)"])
    } catch {
        #expect(Bool(false), "the intent must expose a typed persistence error")
    }
}

@Test
func failedReadBackExposesPreviousIntensity() async {
    let store = TraceStrengthStore(
        intensity: .four,
        readBackValue: .three
    )
    let intent = SetStrengthIntent(
        delta: 1,
        dependencies: IntentDependencies(store: store)
    )

    do {
        _ = try await intent.perform()
        #expect(Bool(false), "a mismatched read-back must not be reported as success")
    } catch let error as SetStrengthIntentError {
        #expect(error == .readBackFailed(previousIntensity: .four, observedIntensity: .three))
        #expect(store.operations == ["persist(5)", "readBack(3)"])
    } catch {
        #expect(Bool(false), "the intent must expose a typed read-back error")
    }
}

@Test
func frameworkPackageAndHostRegistrationAreAvailable() {
    #expect(MaeumjaroAppIntentsPackage.includedPackages.isEmpty)
}
