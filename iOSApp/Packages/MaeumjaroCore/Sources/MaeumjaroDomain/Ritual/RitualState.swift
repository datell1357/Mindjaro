import Foundation

public enum RitualPhase: String, Codable, CaseIterable, Hashable, Sendable {
    case locked
    case unlocking
    case ready
    case holdPending
    case holding
    case paused
    case relocking
    case saving
    case saveFailed
    case completed
}

public struct RitualConfiguration: Equatable, Sendable {
    public let intensity: Intensity
    public let interactionWidth: Double
    public let source: EventSource
    public let startedAtUTC: Date?

    public init(
        intensity: Intensity,
        interactionWidth: Double = 320,
        source: EventSource = .app,
        startedAtUTC: Date? = nil
    ) {
        self.intensity = intensity
        self.interactionWidth = interactionWidth
        self.source = source
        self.startedAtUTC = startedAtUTC
    }
}

public struct RitualState: Equatable, Sendable {
    public internal(set) var phase: RitualPhase
    public let intensity: Intensity
    public internal(set) var progress: Double
    public internal(set) var ringTurnDegrees: Double
    public internal(set) var sessionID: UUID?
    public internal(set) var activeSequenceID: UUID?
    public internal(set) var interruptedCount: Int

    public var remainingFill: Double {
        IntensityProfile(intensity: intensity).initialFill * (1 - progress)
    }

    public init(intensity: Intensity) {
        phase = .locked
        self.intensity = intensity
        progress = 0
        ringTurnDegrees = 0
        sessionID = nil
        activeSequenceID = nil
        interruptedCount = 0
    }
}
