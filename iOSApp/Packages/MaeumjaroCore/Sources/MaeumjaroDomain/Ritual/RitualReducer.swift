import Foundation

public struct RitualReducer: Sendable {
    public internal(set) var state: RitualState
    public let profile: IntensityProfile

    let configuration: RitualConfiguration
    let uuidGenerator: any UUIDGenerator
    var lastMonotonicTimeMilliseconds: Int64?
    var pendingStartedAtMilliseconds: Int64?
    var holdSegmentStartedAtMilliseconds: Int64?
    var firstHoldStartedAtMilliseconds: Int64?
    var accumulatedHoldMilliseconds: Int64 = 0
    var ringDirection: Double = 1
    var startCueEmitted = false
    var emittedProgressCues: Set<Int> = []
    var completionSeed: RitualCompletionSeed?
    var usedPointerSequenceIDs: Set<UUID> = []
    var relockStartedWhilePaused = false

    public init(
        configuration: RitualConfiguration,
        uuidGenerator: any UUIDGenerator = SystemUUIDGenerator()
    ) {
        self.configuration = configuration
        self.uuidGenerator = uuidGenerator
        profile = IntensityProfile(intensity: configuration.intensity)
        state = RitualState(intensity: configuration.intensity)
    }

    public init(
        intensity: Intensity,
        uuidGenerator: any UUIDGenerator = SystemUUIDGenerator()
    ) {
        self.init(configuration: RitualConfiguration(intensity: intensity), uuidGenerator: uuidGenerator)
    }

    public static func threshold(forInteractionWidth width: Double) -> Double {
        max(44, min(56, width * 0.18))
    }

    public static func horizontalIntent(dx: Double, dy: Double) -> Bool {
        abs(dx) >= 1.25 * abs(dy)
    }

    @discardableResult
    public mutating func reduce(_ action: RitualAction) -> [RitualEffect] {
        switch action {
        case let .pointerDown(sequenceID, time):
            if state.phase == .locked {
                beginPointer(sequenceID, at: time)
            } else {
                beginHoldPointer(sequenceID, at: time)
            }
        case let .assistiveStart(sequenceID, time), let .assistiveResume(sequenceID, time):
            beginHoldPointer(sequenceID, at: time)
        case let .pointerMove(sequenceID, time, translation): return move(sequenceID, at: time, by: translation)
        case let .pointerUp(sequenceID, time, translation): return up(sequenceID, at: time, translation: translation)
        case let .pointerCancel(sequenceID, time): return cancel(sequenceID, at: time)
        case let .advance(sequenceID, time): return advance(sequenceID, at: time)
        case let .background(sequenceID, time), let .sceneInactive(sequenceID, time):
            return interrupt(sequenceID, at: time)
        case let .assistivePause(sequenceID, time): return cancel(sequenceID, at: time)
        case let .reset(sequenceID, time): return reset(sequenceID, at: time)
        case let .recordingSucceeded(sessionID, sequenceID, time),
             let .recordingAlreadyRecorded(sessionID, sequenceID, time):
            return recordingResult(sessionID, sequenceID: sequenceID, at: time)
        case let .recordingFailed(sessionID, sequenceID, time):
            return recordingFailure(sessionID, sequenceID: sequenceID, at: time)
        case let .retryRecording(sessionID, sequenceID, time):
            return retry(sessionID, sequenceID: sequenceID, at: time)
        }
        return []
    }

    private mutating func beginPointer(_ sequenceID: UUID, at time: Int64) {
        guard state.phase == .locked, !usedPointerSequenceIDs.contains(sequenceID) else { return }
        usedPointerSequenceIDs.insert(sequenceID)
        state.activeSequenceID = sequenceID
        _ = observe(time)
        state.phase = .unlocking
        state.ringTurnDegrees = 0
    }

    private mutating func beginHoldPointer(_ sequenceID: UUID, at time: Int64) {
        guard (state.phase == .ready || state.phase == .paused),
              !usedPointerSequenceIDs.contains(sequenceID) else { return }
        usedPointerSequenceIDs.insert(sequenceID)
        state.activeSequenceID = sequenceID
        relockStartedWhilePaused = state.phase == .paused
        let now = observe(time)
        pendingStartedAtMilliseconds = now
        state.phase = .holdPending
    }

    private mutating func move(
        _ sequenceID: UUID,
        at time: Int64,
        by translation: RitualTranslation
    ) -> [RitualEffect] {
        guard state.activeSequenceID == sequenceID else { return [] }
        let now = observe(time)
        switch state.phase {
        case .unlocking:
            if abs(translation.dy) > 8, !Self.horizontalIntent(dx: translation.dx, dy: translation.dy) {
                // A vertical-dominant gesture cancels the unlock sequence;
                // later events from this pointer sequence must be ignored.
                resetToLocked()
            } else {
                updateUnlockTurn(translation.dx)
            }
        case .holdPending:
            guard let pending = pendingStartedAtMilliseconds else { return [] }
            if now >= pending + 120 {
                return beginHolding(at: pending + 120)
            } else if abs(translation.dy) > 8, !Self.horizontalIntent(dx: translation.dx, dy: translation.dy) {
                cancelPending()
            } else if abs(translation.dx) > 8, Self.horizontalIntent(dx: translation.dx, dy: translation.dy) {
                state.phase = .relocking
                ringDirection = translation.dx >= 0 ? 1 : -1
                updateRelockTurn(translation.dx)
            }
        case .relocking:
            if abs(translation.dy) > 8, !Self.horizontalIntent(dx: translation.dx, dy: translation.dy) {
                cancelRelock()
            } else {
                updateRelockTurn(translation.dx)
            }
        case .locked, .ready, .holding, .paused, .saving, .saveFailed, .completed:
            break
        }
        return []
    }

    private mutating func up(
        _ sequenceID: UUID,
        at time: Int64,
        translation: RitualTranslation
    ) -> [RitualEffect] {
        guard state.activeSequenceID == sequenceID else { return [] }
        let now = observe(time)
        switch state.phase {
        case .unlocking:
            updateUnlockTurn(translation.dx)
            if validSwipe(translation.dx, translation.dy) {
                state.phase = .ready
                state.ringTurnDegrees = ringDirection * 180
            } else {
                resetToLocked()
            }
            state.activeSequenceID = nil
        case .relocking:
            updateRelockTurn(translation.dx)
            if validSwipe(translation.dx, translation.dy) {
                let committedTurn = state.ringTurnDegrees
                resetToLocked()
                // Preserve the visual release target; the next pointer-down
                // resets this transient turn back to zero.
                state.ringTurnDegrees = committedTurn
            } else {
                state.phase = relockStartedWhilePaused ? .paused : .ready
                state.ringTurnDegrees = ringDirection * 180
                state.activeSequenceID = nil
                relockStartedWhilePaused = false
            }
        case .holdPending:
            var effects = [RitualEffect]()
            if let pending = pendingStartedAtMilliseconds, now >= pending + 120 {
                effects += beginHolding(at: pending + 120)
                effects += applyProgress(at: now, allowCompletion: false)
                if state.phase == .holding { pause() }
            } else {
                cancelPending()
            }
            return effects
        case .holding:
            let effects = applyProgress(at: now, allowCompletion: false)
            if state.phase == .holding { pause() }
            return effects
        case .locked, .ready, .paused, .saving, .saveFailed, .completed:
            break
        }
        return []
    }

    private mutating func cancel(_ sequenceID: UUID, at time: Int64) -> [RitualEffect] {
        guard state.activeSequenceID == sequenceID else { return [] }
        let now = observe(time)
        switch state.phase {
        case .holding:
            let effects = applyProgress(at: now, allowCompletion: false)
            if state.phase == .holding { pause() }
            return effects
        case .holdPending:
            if let pending = pendingStartedAtMilliseconds, now >= pending + 120 {
                var effects = beginHolding(at: pending + 120)
                effects += applyProgress(at: now, allowCompletion: false)
                if state.phase == .holding { pause() }
                return effects
            }
            cancelPending()
        case .unlocking:
            resetToLocked()
            state.activeSequenceID = nil
        case .relocking:
            cancelRelock()
        case .locked, .ready, .paused, .saving, .saveFailed, .completed:
            break
        }
        return []
    }

    private mutating func advance(_ sequenceID: UUID, at time: Int64) -> [RitualEffect] {
        guard state.activeSequenceID == sequenceID else { return [] }
        let now = observe(time)
        var effects = [RitualEffect]()
        if state.phase == .holdPending, let pending = pendingStartedAtMilliseconds, now >= pending + 120 {
            effects += beginHolding(at: pending + 120)
        }
        if state.phase == .holding { effects += applyProgress(at: now) }
        return effects
    }

    private mutating func interrupt(_ sequenceID: UUID, at time: Int64) -> [RitualEffect] {
        guard state.activeSequenceID == sequenceID else { return [] }
        let now = observe(time)
        switch state.phase {
        case .holding:
            let effects = applyProgress(at: now, allowCompletion: false)
            if state.phase == .holding { pause() }
            return effects
        case .holdPending:
            if let pending = pendingStartedAtMilliseconds, now >= pending + 120 {
                var effects = beginHolding(at: pending + 120)
                effects += applyProgress(at: now, allowCompletion: false)
                if state.phase == .holding { pause() }
                return effects
            }
            cancelPending()
        case .unlocking:
            resetToLocked()
            state.activeSequenceID = nil
        case .relocking:
            cancelRelock()
        case .locked, .ready, .paused, .saving, .saveFailed, .completed:
            break
        }
        return []
    }

    private mutating func reset(_ sequenceID: UUID, at time: Int64) -> [RitualEffect] {
        guard state.phase != .saving else { return [] }
        _ = observe(time)
        resetToLocked()
        return []
    }

}
