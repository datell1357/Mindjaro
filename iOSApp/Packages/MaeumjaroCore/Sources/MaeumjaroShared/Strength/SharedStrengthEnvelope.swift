import Foundation
import MaeumjaroDomain

public enum SharedSnapshotWriter: String, Codable, CaseIterable, Hashable, Sendable {
    case app
    case intent
}

public struct SharedStrengthEnvelope: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 1

    public let schemaVersion: Int
    public let updatedAt: Date
    public let writer: SharedSnapshotWriter
    public let revision: Int
    public let intensity: Intensity

    public init(
        intensity: Intensity,
        writer: SharedSnapshotWriter,
        updatedAt: Date,
        revision: Int,
        schemaVersion: Int = SharedStrengthEnvelope.currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.updatedAt = updatedAt
        self.writer = writer
        self.revision = revision
        self.intensity = intensity
    }

    public var strength: Intensity { intensity }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case updatedAt
        case writer
        case revision
        case intensity
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        guard schemaVersion == Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .schemaVersion,
                in: container,
                debugDescription: "Unsupported shared strength schema."
            )
        }
        let revision = try container.decode(Int.self, forKey: .revision)
        guard revision >= 1 else {
            throw DecodingError.dataCorruptedError(
                forKey: .revision,
                in: container,
                debugDescription: "Shared strength revision must be positive."
            )
        }
        self.init(
            intensity: try container.decode(Intensity.self, forKey: .intensity),
            writer: try container.decode(SharedSnapshotWriter.self, forKey: .writer),
            updatedAt: try container.decode(Date.self, forKey: .updatedAt),
            revision: revision,
            schemaVersion: schemaVersion
        )
    }
}

public enum SharedStrengthStoreError: Error, Equatable, Sendable {
    case encodingFailed(previousIntensity: Intensity)
    case writeFailed(previousIntensity: Intensity)
    case readBackFailed(previousIntensity: Intensity, observedEnvelope: SharedStrengthEnvelope?)

    public var previousIntensity: Intensity {
        switch self {
        case let .encodingFailed(previousIntensity),
             let .writeFailed(previousIntensity),
             let .readBackFailed(previousIntensity, _):
            return previousIntensity
        }
    }

    public var observedIntensity: Intensity? {
        guard case let .readBackFailed(_, observedEnvelope) = self else { return nil }
        return observedEnvelope?.intensity
    }
}
