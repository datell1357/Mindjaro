import Foundation

public enum PhraseCategory: String, Codable, CaseIterable, Hashable, Sendable {
    case separation
    case impermanence
    case autonomy
    case redirect
    case nonjudgment
}

public enum PhraseTone: String, Codable, CaseIterable, Hashable, Sendable {
    case gentle
    case neutral
    case firm
}

public enum PhraseTonePreference: String, Codable, CaseIterable, Hashable, Sendable {
    case automatic
    case gentle
    case neutral
    case firm
}

public enum PhraseSafetyStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case approved
    case pending
    case rejected
}

public struct Phrase: Codable, Equatable, Hashable, Sendable {
    public let phraseID: String
    public let category: PhraseCategory
    public let tone: PhraseTone
    public let minimumIntensity: Intensity
    public let maximumIntensity: Intensity
    public let textKO: String
    public let safetyStatus: PhraseSafetyStatus
    public let contentVersion: Int

    public init(
        phraseID: String,
        category: PhraseCategory,
        tone: PhraseTone,
        minimumIntensity: Intensity,
        maximumIntensity: Intensity,
        textKO: String,
        safetyStatus: PhraseSafetyStatus = .approved,
        contentVersion: Int = 1
    ) {
        self.phraseID = phraseID
        self.category = category
        self.tone = tone
        self.minimumIntensity = minimumIntensity
        self.maximumIntensity = maximumIntensity
        self.textKO = textKO
        self.safetyStatus = safetyStatus
        self.contentVersion = contentVersion
    }

    public var isEligible: Bool {
        safetyStatus == .approved && minimumIntensity <= maximumIntensity
    }

    /// The localized presentation value. `phraseID` remains the persistence key.
    public var displayText: String {
        Bundle.module.localizedString(forKey: phraseID, value: textKO, table: nil)
    }

    private enum CodingKeys: String, CodingKey {
        case phraseID
        case category
        case tone
        case minimumIntensity
        case maximumIntensity
        case textKO
        case safetyStatus
        case contentVersion
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let phraseID = try container.decode(String.self, forKey: .phraseID)
        let textKO = try container.decode(String.self, forKey: .textKO)
        let contentVersion = try container.decode(Int.self, forKey: .contentVersion)
        let minimumIntensity = try container.decode(Intensity.self, forKey: .minimumIntensity)
        let maximumIntensity = try container.decode(Intensity.self, forKey: .maximumIntensity)

        guard !phraseID.isEmpty, !textKO.isEmpty, contentVersion >= 1,
              minimumIntensity <= maximumIntensity
        else {
            throw DecodingError.dataCorruptedError(
                forKey: .phraseID,
                in: container,
                debugDescription: "Phrase catalog entry is outside the approved contract."
            )
        }

        try self.init(
            phraseID: phraseID,
            category: container.decode(PhraseCategory.self, forKey: .category),
            tone: container.decode(PhraseTone.self, forKey: .tone),
            minimumIntensity: minimumIntensity,
            maximumIntensity: maximumIntensity,
            textKO: textKO,
            safetyStatus: container.decode(PhraseSafetyStatus.self, forKey: .safetyStatus),
            contentVersion: contentVersion
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(phraseID, forKey: .phraseID)
        try container.encode(category, forKey: .category)
        try container.encode(tone, forKey: .tone)
        try container.encode(minimumIntensity, forKey: .minimumIntensity)
        try container.encode(maximumIntensity, forKey: .maximumIntensity)
        try container.encode(textKO, forKey: .textKO)
        try container.encode(safetyStatus, forKey: .safetyStatus)
        try container.encode(contentVersion, forKey: .contentVersion)
    }
}
