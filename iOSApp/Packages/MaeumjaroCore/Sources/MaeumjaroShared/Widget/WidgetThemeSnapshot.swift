import Foundation
import MaeumjaroDomain

public struct WidgetThemeSnapshot: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let updatedAt: Date
    public let writer: SharedSnapshotWriter
    public let revision: Int
    public let themeID: ThemeID

    public init(
        themeID: ThemeID,
        writer: SharedSnapshotWriter,
        updatedAt: Date,
        revision: Int,
        schemaVersion: Int = WidgetThemeSnapshot.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.updatedAt = updatedAt
        self.writer = writer
        self.revision = revision
        self.themeID = themeID
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case updatedAt
        case writer
        case revision
        case themeID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported widget theme schema."
            )
        }
        let revision = try container.decode(Int.self, forKey: .revision)
        guard revision >= 1 else {
            throw DecodingError.dataCorruptedError(
                forKey: .revision,
                in: container,
                debugDescription: "Widget theme revision must be positive."
            )
        }
        self.init(
            themeID: try container.decode(ThemeID.self, forKey: .themeID),
            writer: try container.decode(SharedSnapshotWriter.self, forKey: .writer),
            updatedAt: try container.decode(Date.self, forKey: .updatedAt),
            revision: revision,
            schemaVersion: schemaVersion
        )
    }
}
