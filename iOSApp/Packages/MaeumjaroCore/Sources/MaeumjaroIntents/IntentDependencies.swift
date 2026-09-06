import Foundation
import MaeumjaroDomain
import MaeumjaroShared

public protocol StrengthIntentStore: Sendable {
    func read() async -> Intensity
    func persist(_ intensity: Intensity) async throws
    func readBack() async throws -> Intensity
}

public enum IntentDependenciesError: Error, Equatable, Sendable {
    case unavailable
}

public struct IntentDependencies: Sendable {
    private let store: (any StrengthIntentStore)?

    public init(store: any StrengthIntentStore) {
        self.store = store
    }

    public init(sharedStrengthStore: SharedStrengthStore) {
        store = SharedStrengthIntentStore(store: sharedStrengthStore)
    }

    public init() {
        store = nil
    }

    public static var live: Self {
        guard let defaults = try? AppGroupDefaults() else {
            return Self()
        }
        #if DEBUG
        let scopedDefaults = DebugFixtureNamespace.active(in: defaults)?.scopedDefaults(from: defaults) ?? defaults
        #else
        let scopedDefaults = defaults
        #endif
        return Self(
            sharedStrengthStore: SharedStrengthStore(defaults: scopedDefaults)
        )
    }

    func read() async throws -> Intensity {
        guard let store else { throw IntentDependenciesError.unavailable }
        return await store.read()
    }

    func persist(_ intensity: Intensity) async throws {
        guard let store else { throw IntentDependenciesError.unavailable }
        try await store.persist(intensity)
    }

    func readBack() async throws -> Intensity {
        guard let store else { throw IntentDependenciesError.unavailable }
        return try await store.readBack()
    }
}

private struct SharedStrengthIntentStore: StrengthIntentStore {
    let store: SharedStrengthStore

    func read() async -> Intensity {
        store.read()
    }

    func persist(_ intensity: Intensity) async throws {
        do {
            _ = try store.write(intensity, writer: .intent)
        } catch let error as SharedStrengthStoreError {
            if case let .readBackFailed(_, observedEnvelope) = error {
                throw StrengthIntentStoreError.persistReadBackFailed(
                    observedIntensity: observedEnvelope?.intensity
                )
            }
            throw StrengthIntentStoreError.persistFailed
        } catch {
            throw StrengthIntentStoreError.persistFailed
        }
    }

    func readBack() async throws -> Intensity {
        store.read()
    }
}
