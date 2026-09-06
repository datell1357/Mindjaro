import Foundation
import MaeumjaroDomain

public struct SharedStrengthStore: Sendable {
    private let defaults: AppGroupDefaults

    public init(defaults: AppGroupDefaults) {
        self.defaults = defaults
    }

    public init(storage: any AppGroupDataStore) {
        self.init(defaults: AppGroupDefaults(storage: storage))
    }

    public func read() -> Intensity {
        readEnvelope()?.intensity ?? .default
    }

    public func readEnvelope() -> SharedStrengthEnvelope? {
        guard let data = defaults.data(forKey: AppGroupDefaults.Keys.strength) else { return nil }
        return try? JSONDecoder().decode(SharedStrengthEnvelope.self, from: data)
    }

    @discardableResult
    public func write(
        _ intensity: Intensity,
        writer: SharedSnapshotWriter,
        now: Date = Date()
    ) throws -> Intensity {
        let previous = read()
        let revision = (readEnvelope()?.revision ?? 0) + 1
        let envelope = SharedStrengthEnvelope(
            intensity: intensity,
            writer: writer,
            updatedAt: now,
            revision: revision
        )
        let encoded: Data
        do {
            encoded = try JSONEncoder().encode(envelope)
        } catch {
            throw SharedStrengthStoreError.encodingFailed(previousIntensity: previous)
        }

        do {
            try defaults.set(encoded, forKey: AppGroupDefaults.Keys.strength)
        } catch {
            throw SharedStrengthStoreError.writeFailed(previousIntensity: previous)
        }

        let readBack = readEnvelope()
        guard let readBack, readBack == envelope else {
            throw SharedStrengthStoreError.readBackFailed(
                previousIntensity: previous,
                observedEnvelope: readBack
            )
        }
        return readBack.intensity
    }
}
