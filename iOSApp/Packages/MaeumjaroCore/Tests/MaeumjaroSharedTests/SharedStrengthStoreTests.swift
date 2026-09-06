import Foundation
import Testing

import MaeumjaroDomain
import MaeumjaroShared

private func makeStrengthDefaults() -> AppGroupDefaults {
    AppGroupDefaults(storage: MemoryDataStore())
}

private final class ReadBackRaceDataStore: AppGroupDataStore, @unchecked Sendable {
    private let lock = NSLock()
    private let newerBytes: Data
    private var values: [String: Data] = [:]

    init(newerBytes: Data) {
        self.newerBytes = newerBytes
    }

    func data(forKey key: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return values[key]
    }

    func set(_ data: Data, forKey key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        values[key] = newerBytes
    }

    func remove(forKey key: String) throws {
        lock.lock()
        defer { lock.unlock() }
        values.removeValue(forKey: key)
    }
}

@Test
func missingStrengthFallsBackToDefaultWithoutCreatingARecord() {
    let defaults = makeStrengthDefaults()
    let store = SharedStrengthStore(defaults: defaults)

    #expect(store.read() == .default)
    #expect(defaults.data(forKey: AppGroupDefaults.Keys.strength) == nil)
}

@Test
func sequentialAppAndIntentWritesReadBackTheLastValidStrengthAndRevision() throws {
    let defaults = makeStrengthDefaults()
    let store = SharedStrengthStore(defaults: defaults)
    let firstDate = Date(timeIntervalSince1970: 1_757_000_000)
    let secondDate = firstDate.addingTimeInterval(1)

    let first = try store.write(.two, writer: .app, now: firstDate)
    let second = try store.write(.five, writer: .intent, now: secondDate)

    #expect(first == .two)
    #expect(second == .five)
    #expect(store.read() == .five)
    #expect(store.readEnvelope()?.writer == .intent)
    #expect(store.readEnvelope()?.revision == 2)
    #expect(store.readEnvelope()?.updatedAt == secondDate)
}

@Test
func corruptStrengthBytesArePreservedAndReturnTheDefault() throws {
    let defaults = makeStrengthDefaults()
    let corrupt = Data("not-json".utf8)
    try defaults.set(corrupt, forKey: AppGroupDefaults.Keys.strength)
    let store = SharedStrengthStore(defaults: defaults)

    #expect(store.read() == .default)
    #expect(defaults.data(forKey: AppGroupDefaults.Keys.strength) == corrupt)
}

@Test
func unknownStrengthSchemaIsPreservedAndReturnsTheDefault() throws {
    let defaults = makeStrengthDefaults()
    let unknown = try JSONSerialization.data(withJSONObject: [
        "schemaVersion": 99,
        "updatedAt": "2026-09-05T00:00:00Z",
        "writer": "app",
        "revision": 4,
        "intensity": 5
    ])
    try defaults.set(unknown, forKey: AppGroupDefaults.Keys.strength)
    let store = SharedStrengthStore(defaults: defaults)

    #expect(store.read() == .default)
    #expect(defaults.data(forKey: AppGroupDefaults.Keys.strength) == unknown)
}

@Test
func outOfRangeStrengthPayloadIsPreservedAndReturnsTheDefault() throws {
    let defaults = makeStrengthDefaults()
    let outOfRange = try JSONSerialization.data(withJSONObject: [
        "schemaVersion": 1,
        "updatedAt": 0,
        "writer": "app",
        "revision": 1,
        "intensity": 6
    ])
    try defaults.set(outOfRange, forKey: AppGroupDefaults.Keys.strength)
    let store = SharedStrengthStore(defaults: defaults)

    #expect(store.read() == .default)
    #expect(defaults.data(forKey: AppGroupDefaults.Keys.strength) == outOfRange)
}

@Test
func failedStrengthWriteReportsThePreviousIntensityAndLeavesTheOldBytes() throws {
    let storage = MemoryDataStore()
    let defaults = AppGroupDefaults(storage: storage)
    let store = SharedStrengthStore(defaults: defaults)
    _ = try store.write(.two, writer: .app, now: Date(timeIntervalSince1970: 1))
    let previousBytes = defaults.data(forKey: AppGroupDefaults.Keys.strength)
    storage.failWrites = true

    do {
        _ = try store.write(.five, writer: .intent, now: Date(timeIntervalSince1970: 2))
        #expect(Bool(false), "a configured storage failure must throw")
    } catch let error as SharedStrengthStoreError {
        #expect(error.previousIntensity == .two)
        #expect(store.read() == .two)
    }

    #expect(defaults.data(forKey: AppGroupDefaults.Keys.strength) == previousBytes)
}

@Test
func readBackFailurePreservesAConcurrentNewerEnvelope() throws {
    let newer = SharedStrengthEnvelope(
        intensity: .five,
        writer: .intent,
        updatedAt: Date(timeIntervalSince1970: 2),
        revision: 2
    )
    let newerBytes = try JSONEncoder().encode(newer)
    let store = SharedStrengthStore(storage: ReadBackRaceDataStore(newerBytes: newerBytes))

    do {
        _ = try store.write(.two, writer: .app, now: Date(timeIntervalSince1970: 1))
        #expect(Bool(false), "a concurrent replacement must fail read-back")
    } catch let error as SharedStrengthStoreError {
        #expect(error.previousIntensity == .default)
        #expect(error.observedIntensity == .five)
    }

    #expect(store.read() == .five)
}

@Test
func invalidIntensityCannotBeEncodedIntoAStrengthEnvelope() {
    #expect(Intensity(rawValue: 0) == nil)
    #expect(Intensity(rawValue: 6) == nil)
}

#if DEBUG
@Test
func debugFixtureSelectionSharesAUuidNamespaceWithoutTouchingProductionKeys() throws {
    let defaults = makeStrengthDefaults()
    let fixtureID = "E7C22E0B-3B7E-48AA-BE26-6E0E5A74BC40"
    let selected = try DebugFixtureNamespace.select(
        from: ["-MaeumjaroFixtureID", fixtureID],
        in: defaults
    )
    let namespace = try #require(selected)

    #expect(namespace.keyPrefix == "qa.e7c22e0b-3b7e-48aa-be26-6e0e5a74bc40.")
    #expect(DebugFixtureNamespace.active(in: defaults) == namespace)
    let scoped = namespace.scopedDefaults(from: defaults)
    let store = SharedStrengthStore(defaults: scoped)
    _ = try store.write(.four, writer: .app, now: Date(timeIntervalSince1970: 1))

    #expect(defaults.data(forKey: AppGroupDefaults.Keys.strength) == nil)
    #expect(defaults.data(forKey: namespace.keyPrefix + AppGroupDefaults.Keys.strength) != nil)
}
#endif
