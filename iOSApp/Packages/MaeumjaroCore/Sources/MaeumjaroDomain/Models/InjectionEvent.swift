import Foundation

public struct InjectionEvent: Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public let startedAtUTC: Date
    public let completedAtUTC: Date
    public let createdAtUTC: Date
    public let eventLocalDate: String
    public let timezoneOffsetMinutes: Int
    public let intensity: Intensity
    public let source: EventSource
    public let phraseID: String
    public let animationDurationMilliseconds: Int
    public let interruptedCount: Int
    public let appVersion: String

    public init(
        id: UUID,
        startedAtUTC: Date,
        completedAtUTC: Date,
        createdAtUTC: Date,
        eventLocalDate: String,
        timezoneOffsetMinutes: Int,
        intensity: Intensity,
        source: EventSource,
        phraseID: String,
        animationDurationMilliseconds: Int,
        interruptedCount: Int,
        appVersion: String
    ) {
        self.id = id
        self.startedAtUTC = startedAtUTC
        self.completedAtUTC = completedAtUTC
        self.createdAtUTC = createdAtUTC
        self.eventLocalDate = eventLocalDate
        self.timezoneOffsetMinutes = timezoneOffsetMinutes
        self.intensity = intensity
        self.source = source
        self.phraseID = phraseID
        self.animationDurationMilliseconds = animationDurationMilliseconds
        self.interruptedCount = interruptedCount
        self.appVersion = appVersion
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case startedAtUTC
        case completedAtUTC
        case createdAtUTC
        case eventLocalDate
        case timezoneOffsetMinutes
        case intensity
        case source
        case phraseID
        case animationDurationMilliseconds
        case interruptedCount
        case appVersion
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let eventLocalDate = try container.decode(String.self, forKey: .eventLocalDate)
        let phraseID = try container.decode(String.self, forKey: .phraseID)
        let animationDurationMilliseconds = try container.decode(
            Int.self,
            forKey: .animationDurationMilliseconds
        )
        let interruptedCount = try container.decode(Int.self, forKey: .interruptedCount)
        let appVersion = try container.decode(String.self, forKey: .appVersion)

        guard !eventLocalDate.isEmpty, !phraseID.isEmpty,
              animationDurationMilliseconds >= 0, interruptedCount >= 0,
              !appVersion.isEmpty else {
            throw DecodingError.dataCorruptedError(
                forKey: .eventLocalDate,
                in: container,
                debugDescription: "InjectionEvent contains an invalid completion field."
            )
        }

        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            startedAtUTC: try container.decode(Date.self, forKey: .startedAtUTC),
            completedAtUTC: try container.decode(Date.self, forKey: .completedAtUTC),
            createdAtUTC: try container.decode(Date.self, forKey: .createdAtUTC),
            eventLocalDate: eventLocalDate,
            timezoneOffsetMinutes: try container.decode(Int.self, forKey: .timezoneOffsetMinutes),
            intensity: try container.decode(Intensity.self, forKey: .intensity),
            source: try container.decode(EventSource.self, forKey: .source),
            phraseID: phraseID,
            animationDurationMilliseconds: animationDurationMilliseconds,
            interruptedCount: interruptedCount,
            appVersion: appVersion
        )
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(startedAtUTC, forKey: .startedAtUTC)
        try container.encode(completedAtUTC, forKey: .completedAtUTC)
        try container.encode(createdAtUTC, forKey: .createdAtUTC)
        try container.encode(eventLocalDate, forKey: .eventLocalDate)
        try container.encode(timezoneOffsetMinutes, forKey: .timezoneOffsetMinutes)
        try container.encode(intensity, forKey: .intensity)
        try container.encode(source, forKey: .source)
        try container.encode(phraseID, forKey: .phraseID)
        try container.encode(animationDurationMilliseconds, forKey: .animationDurationMilliseconds)
        try container.encode(interruptedCount, forKey: .interruptedCount)
        try container.encode(appVersion, forKey: .appVersion)
    }
}
