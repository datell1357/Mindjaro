import Foundation
import MaeumjaroDomain

public struct WidgetThemeStore: Sendable {
    private let defaults: AppGroupDefaults

    public init(defaults: AppGroupDefaults) {
        self.defaults = defaults
    }

    public init(storage: any AppGroupDataStore) {
        self.init(defaults: AppGroupDefaults(storage: storage))
    }

    public func read() -> ThemeID {
        readSnapshot()?.themeID ?? .default
    }

    public func readSnapshot() -> WidgetThemeSnapshot? {
        guard let data = defaults.data(forKey: AppGroupDefaults.Keys.widgetTheme) else { return nil }
        return try? JSONDecoder().decode(WidgetThemeSnapshot.self, from: data)
    }

    @discardableResult
    public func write(_ snapshot: WidgetThemeSnapshot) throws -> WidgetThemeSnapshot {
        let revision = (readSnapshot()?.revision ?? 0) + 1
        let stored = WidgetThemeSnapshot(
            themeID: snapshot.themeID,
            writer: snapshot.writer,
            updatedAt: snapshot.updatedAt,
            revision: revision
        )
        let encoded: Data
        do {
            encoded = try JSONEncoder().encode(stored)
        } catch {
            throw WidgetThemeStoreError.encodingFailed
        }
        do {
            try defaults.set(encoded, forKey: AppGroupDefaults.Keys.widgetTheme)
        } catch {
            throw WidgetThemeStoreError.writeFailed
        }
        guard readSnapshot() == stored else {
            throw WidgetThemeStoreError.readBackFailed
        }
        return stored
    }

    @discardableResult
    public func write(
        _ themeID: ThemeID,
        writer: SharedSnapshotWriter,
        now: Date = Date()
    ) throws -> WidgetThemeSnapshot {
        try write(WidgetThemeSnapshot(
            themeID: themeID,
            writer: writer,
            updatedAt: now,
            revision: 1
        ))
    }
}

public enum WidgetThemeStoreError: Error, Equatable, Sendable {
    case encodingFailed
    case writeFailed
    case readBackFailed
}
