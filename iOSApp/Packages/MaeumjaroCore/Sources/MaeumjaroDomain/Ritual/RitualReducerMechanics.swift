import Foundation

extension RitualReducer {
    mutating func beginHolding(at time: Int64) -> [RitualEffect] {
        guard state.phase == .holdPending else { return [] }
        let session = state.sessionID ?? uuidGenerator.makeUUID()
        state.sessionID = session
        state.phase = .holding
        holdSegmentStartedAtMilliseconds = time
        firstHoldStartedAtMilliseconds = firstHoldStartedAtMilliseconds ?? time
        pendingStartedAtMilliseconds = nil
        guard !startCueEmitted else { return [] }
        startCueEmitted = true
        return [.startCue]
    }

    mutating func applyProgress(at time: Int64, allowCompletion: Bool = true) -> [RitualEffect] {
        guard state.phase == .holding, let segmentStart = holdSegmentStartedAtMilliseconds else { return [] }
        let delta = max(0, time - segmentStart)
        accumulatedHoldMilliseconds = max(accumulatedHoldMilliseconds, accumulatedHoldMilliseconds + delta)
        holdSegmentStartedAtMilliseconds = time
        state.progress = profile.progress(atElapsedMilliseconds: accumulatedHoldMilliseconds)
        var effects: [RitualEffect] = []
        for (index, threshold) in profile.progressPulseThresholds.enumerated() {
            guard !emittedProgressCues.contains(index), state.progress >= threshold else { continue }
            emittedProgressCues.insert(index)
            effects.append(.progressCue(index: index + 1, threshold: threshold))
        }
        if allowCompletion, state.progress >= 1 { effects += complete() }
        return effects
    }

    mutating func complete() -> [RitualEffect] {
        guard state.phase == .holding, let sessionID = state.sessionID else { return [] }
        state.progress = 1
        state.phase = .saving
        holdSegmentStartedAtMilliseconds = nil
        let seed = RitualCompletionSeed(
            sessionID: sessionID,
            intensity: configuration.intensity,
            animationDurationMilliseconds: profile.durationMilliseconds,
            interruptedCount: state.interruptedCount,
            source: configuration.source,
            startedAtUTC: configuration.startedAtUTC,
            startedAtMonotonicTimeMilliseconds: firstHoldStartedAtMilliseconds ?? 0
        )
        completionSeed = seed
        return [.completionCue, .persistCompletion(seed)]
    }

    mutating func pause() {
        holdSegmentStartedAtMilliseconds = nil
        state.phase = .paused
        state.interruptedCount += 1
        state.activeSequenceID = nil
    }

    mutating func recordingResult(
        _ sessionID: UUID,
        sequenceID: UUID,
        at time: Int64
    ) -> [RitualEffect] {
        guard state.phase == .saving, state.sessionID == sessionID, state.activeSequenceID == sequenceID else { return [] }
        _ = observe(time)
        state.phase = .completed
        state.activeSequenceID = nil
        return [.completed(sessionID: sessionID)]
    }

    mutating func recordingFailure(
        _ sessionID: UUID,
        sequenceID: UUID,
        at time: Int64
    ) -> [RitualEffect] {
        guard state.phase == .saving, state.sessionID == sessionID, state.activeSequenceID == sequenceID else { return [] }
        _ = observe(time)
        state.phase = .saveFailed
        state.activeSequenceID = nil
        return [.recordingFailed(sessionID: sessionID)]
    }

    mutating func retry(
        _ sessionID: UUID,
        sequenceID: UUID,
        at time: Int64
    ) -> [RitualEffect] {
        guard state.phase == .saveFailed, state.sessionID == sessionID, let seed = completionSeed else { return [] }
        state.activeSequenceID = sequenceID
        lastMonotonicTimeMilliseconds = max(lastMonotonicTimeMilliseconds ?? time, time)
        state.phase = .saving
        return [.persistCompletion(seed)]
    }

    mutating func observe(_ time: Int64) -> Int64 {
        let observed = max(time, lastMonotonicTimeMilliseconds ?? time)
        lastMonotonicTimeMilliseconds = observed
        return observed
    }

    func validSwipe(_ dx: Double, _ dy: Double) -> Bool {
        Self.horizontalIntent(dx: dx, dy: dy) && abs(dx) >= Self.threshold(forInteractionWidth: configuration.interactionWidth)
    }

    mutating func updateUnlockTurn(_ dx: Double) {
        ringDirection = dx >= 0 ? 1 : -1
        let progress = min(1, abs(dx) / Self.threshold(forInteractionWidth: configuration.interactionWidth))
        state.ringTurnDegrees = ringDirection * 180 * progress
    }

    mutating func updateRelockTurn(_ dx: Double) {
        ringDirection = dx >= 0 ? 1 : -1
        let progress = min(1, abs(dx) / Self.threshold(forInteractionWidth: configuration.interactionWidth))
        state.ringTurnDegrees = ringDirection * (180 + 180 * progress)
    }

    mutating func cancelPending() {
        pendingStartedAtMilliseconds = nil
        state.activeSequenceID = nil
        state.phase = state.sessionID == nil ? .ready : .paused
        relockStartedWhilePaused = false
    }

    mutating func cancelRelock() {
        state.phase = relockStartedWhilePaused ? .paused : .ready
        state.ringTurnDegrees = ringDirection * 180
        state.activeSequenceID = nil
        relockStartedWhilePaused = false
    }

    mutating func resetToLocked() {
        state.phase = .locked
        state.ringTurnDegrees = 0
        state.progress = 0
        state.sessionID = nil
        state.activeSequenceID = nil
        state.interruptedCount = 0
        pendingStartedAtMilliseconds = nil
        holdSegmentStartedAtMilliseconds = nil
        firstHoldStartedAtMilliseconds = nil
        accumulatedHoldMilliseconds = 0
        startCueEmitted = false
        emittedProgressCues.removeAll()
        completionSeed = nil
        relockStartedWhilePaused = false
    }
}
