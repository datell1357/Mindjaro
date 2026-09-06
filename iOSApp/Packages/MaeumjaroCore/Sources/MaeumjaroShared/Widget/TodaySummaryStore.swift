import Foundation

public struct TodaySummaryStore: Sendable {
    private let defaults: AppGroupDefaults

    public init(defaults: AppGroupDefaults) {
        self.defaults = defaults
    }

    public init(storage: any AppGroupDataStore) {
        self.init(defaults: AppGroupDefaults(storage: storage))
    }

    public func read(forLocalDate localDate: String) -> TodaySummarySnapshot {
        guard let snapshot = readSnapshot(), snapshot.localDate == localDate else {
            return .empty(for: localDate)
        }
        return snapshot
    }

    public func read(currentLocalDate localDate: String) -> TodaySummarySnapshot {
        read(forLocalDate: localDate)
    }

    public func readSnapshot() -> TodaySummarySnapshot? {
        guard let data = defaults.data(forKey: AppGroupDefaults.Keys.todaySummary) else { return nil }
        return try? JSONDecoder().decode(TodaySummarySnapshot.self, from: data)
    }

    @discardableResult
    public func write(_ snapshot: TodaySummarySnapshot) throws -> TodaySummarySnapshot {
        let revision = (readSnapshot()?.revision ?? 0) + 1
        let stored = TodaySummarySnapshot(
            localDate: snapshot.localDate,
            completionCount: snapshot.completionCount,
            intensitySum: snapshot.intensitySum,
            writer: snapshot.writer,
            updatedAt: snapshot.updatedAt,
            revision: revision
        )
        let encoded: Data
        do {
            encoded = try JSONEncoder().encode(stored)
        } catch {
            throw TodaySummaryStoreError.encodingFailed
        }
        do {
            try defaults.set(encoded, forKey: AppGroupDefaults.Keys.todaySummary)
        } catch {
            throw TodaySummaryStoreError.writeFailed
        }
        guard readSnapshot() == stored else {
            throw TodaySummaryStoreError.readBackFailed
        }
        return stored
    }
}
