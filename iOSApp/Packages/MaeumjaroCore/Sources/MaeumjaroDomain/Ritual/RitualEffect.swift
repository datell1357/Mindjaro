import Foundation

public struct RitualCompletionSeed: Equatable, Sendable {
    public let sessionID: UUID
    public let intensity: Intensity
    public let animationDurationMilliseconds: Int
    public let interruptedCount: Int
    public let source: EventSource
    public let startedAtUTC: Date?
    public let startedAtMonotonicTimeMilliseconds: Int64

    public init(
        sessionID: UUID,
        intensity: Intensity,
        animationDurationMilliseconds: Int,
        interruptedCount: Int,
        source: EventSource,
        startedAtUTC: Date?,
        startedAtMonotonicTimeMilliseconds: Int64
    ) {
        self.sessionID = sessionID
        self.intensity = intensity
        self.animationDurationMilliseconds = animationDurationMilliseconds
        self.interruptedCount = interruptedCount
        self.source = source
        self.startedAtUTC = startedAtUTC
        self.startedAtMonotonicTimeMilliseconds = startedAtMonotonicTimeMilliseconds
    }
}

public enum RitualEffect: Equatable, Sendable {
    case startCue
    case progressCue(index: Int, threshold: Double)
    case completionCue
    case persistCompletion(RitualCompletionSeed)
    case recordingFailed(sessionID: UUID)
    case completed(sessionID: UUID)

    public var isProgressCue: Bool {
        switch self {
        case .progressCue: true
        case .startCue, .completionCue, .persistCompletion, .recordingFailed, .completed: false
        }
    }

    public var isPersistCompletion: Bool {
        switch self {
        case .persistCompletion: true
        case .startCue, .progressCue, .completionCue, .recordingFailed, .completed: false
        }
    }

    public var completionSessionID: UUID? {
        switch self {
        case let .persistCompletion(seed): seed.sessionID
        case let .recordingFailed(sessionID), let .completed(sessionID): sessionID
        case .startCue, .progressCue, .completionCue: nil
        }
    }
}
