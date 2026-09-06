import Foundation

public struct RitualTranslation: Equatable, Sendable {
    public let dx: Double
    public let dy: Double

    public static let zero = Self(dx: 0, dy: 0)

    public init(dx: Double, dy: Double) {
        self.dx = dx
        self.dy = dy
    }
}

public enum RitualAction: Equatable, Sendable {
    case pointerDown(sequenceID: UUID, monotonicTimeMilliseconds: Int64)
    case pointerMove(
        sequenceID: UUID,
        monotonicTimeMilliseconds: Int64,
        translation: RitualTranslation
    )
    case pointerUp(
        sequenceID: UUID,
        monotonicTimeMilliseconds: Int64,
        translation: RitualTranslation
    )
    case pointerCancel(sequenceID: UUID, monotonicTimeMilliseconds: Int64)
    case advance(sequenceID: UUID, monotonicTimeMilliseconds: Int64)
    case background(sequenceID: UUID, monotonicTimeMilliseconds: Int64)
    case sceneInactive(sequenceID: UUID, monotonicTimeMilliseconds: Int64)
    case assistiveStart(sequenceID: UUID, monotonicTimeMilliseconds: Int64)
    case assistiveResume(sequenceID: UUID, monotonicTimeMilliseconds: Int64)
    case assistivePause(sequenceID: UUID, monotonicTimeMilliseconds: Int64)
    case reset(sequenceID: UUID, monotonicTimeMilliseconds: Int64)
    case recordingSucceeded(
        sessionID: UUID,
        sequenceID: UUID,
        monotonicTimeMilliseconds: Int64
    )
    case recordingAlreadyRecorded(
        sessionID: UUID,
        sequenceID: UUID,
        monotonicTimeMilliseconds: Int64
    )
    case recordingFailed(
        sessionID: UUID,
        sequenceID: UUID,
        monotonicTimeMilliseconds: Int64
    )
    case retryRecording(
        sessionID: UUID,
        sequenceID: UUID,
        monotonicTimeMilliseconds: Int64
    )
}
