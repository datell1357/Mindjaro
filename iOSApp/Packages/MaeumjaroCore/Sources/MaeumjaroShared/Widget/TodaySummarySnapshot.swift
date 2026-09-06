import Foundation

public struct TodaySummarySnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let updatedAt: Date
    public let writer: SharedSnapshotWriter
    public let revision: Int
    public let localDate: String
    public let completionCount: Int
    public let intensitySum: Int

    public init(
        localDate: String,
        completionCount: Int,
        intensitySum: Int,
        writer: SharedSnapshotWriter,
        updatedAt: Date,
        revision: Int,
        schemaVersion: Int = TodaySummarySnapshot.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.updatedAt = updatedAt
        self.writer = writer
        self.revision = revision
        self.localDate = localDate
        self.completionCount = completionCount
        self.intensitySum = intensitySum
    }

    public var count: Int { completionCount }
    public var sum: Int { intensitySum }

    public static func empty(for localDate: String) -> Self {
        Self(
            localDate: localDate,
            completionCount: 0,
            intensitySum: 0,
            writer: .app,
            updatedAt: Date(timeIntervalSince1970: 0),
            revision: 0
        )
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case updatedAt
        case writer
        case revision
        case localDate
        case completionCount
        case intensitySum
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported today summary schema."
            )
        }
        let revision = try container.decode(Int.self, forKey: .revision)
        let localDate = try container.decode(String.self, forKey: .localDate)
        let completionCount = try container.decode(Int.self, forKey: .completionCount)
        let intensitySum = try container.decode(Int.self, forKey: .intensitySum)
        guard revision >= 1, !localDate.isEmpty, completionCount >= 0, intensitySum >= 0 else {
            throw DecodingError.dataCorruptedError(
                forKey: .localDate,
                in: container,
                debugDescription: "Today summary contains invalid values."
            )
        }
        self.init(
            localDate: localDate,
            completionCount: completionCount,
            intensitySum: intensitySum,
            writer: try container.decode(SharedSnapshotWriter.self, forKey: .writer),
            updatedAt: try container.decode(Date.self, forKey: .updatedAt),
            revision: revision,
            schemaVersion: schemaVersion
        )
    }
}

public enum TodaySummaryStoreError: Error, Equatable, Sendable {
    case encodingFailed
    case writeFailed
    case readBackFailed
}
