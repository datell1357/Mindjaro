import Foundation
import Testing

import MaeumjaroDomain

@Test
func intensityProfilesUseTheApprovedInitialFillDurationAndPulseTable() {
    let profiles = Intensity.allCases.map(IntensityProfile.init(intensity:))

    #expect(profiles.map(\.initialFill) == [0.2, 0.4, 0.6, 0.8, 1.0])
    #expect(profiles.map(\.durationMilliseconds) == [1200, 1500, 1800, 2200, 3200])
    #expect(profiles.map(\.progressPulseCount) == [1, 2, 3, 4, 5])
    #expect(profiles[2].progressPulseThresholds == [0.25, 0.5, 0.75])
}

@Test
func lockedSwipeCommitsOnlyOnReleaseAndAcceptsBothHorizontalDirections() {
    let sequence = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!
    var reducer = makeReducer()

    #expect(reducer.state.phase == .locked)
    #expect(reducer.reduce(.pointerDown(sequenceID: sequence, monotonicTimeMilliseconds: 0)).isEmpty)
    #expect(reducer.state.phase == .unlocking)
    #expect(reducer.reduce(.pointerMove(
        sequenceID: sequence,
        monotonicTimeMilliseconds: 20,
        translation: RitualTranslation(dx: 56, dy: 1)
    )).isEmpty)
    #expect(reducer.state.phase == .unlocking)
    #expect(reducer.reduce(.pointerUp(
        sequenceID: sequence,
        monotonicTimeMilliseconds: 40,
        translation: RitualTranslation(dx: 56, dy: 1)
    )).isEmpty)
    #expect(reducer.state.phase == .ready)

    let relockSequence = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!
    #expect(reducer.reduce(.pointerDown(sequenceID: relockSequence, monotonicTimeMilliseconds: 100)).isEmpty)
    #expect(reducer.reduce(.pointerMove(
        sequenceID: relockSequence,
        monotonicTimeMilliseconds: 120,
        translation: RitualTranslation(dx: -55, dy: 1)
    )).isEmpty)
    #expect(reducer.state.phase == .relocking)
    #expect(reducer.reduce(.pointerUp(
        sequenceID: relockSequence,
        monotonicTimeMilliseconds: 140,
        translation: RitualTranslation(dx: -55, dy: 1)
    )).isEmpty)
    #expect(reducer.state.phase == .ready)

    let exactRelockSequence = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
    #expect(reducer.reduce(.pointerDown(sequenceID: exactRelockSequence, monotonicTimeMilliseconds: 200)).isEmpty)
    #expect(reducer.reduce(.pointerMove(sequenceID: exactRelockSequence, monotonicTimeMilliseconds: 220, translation: RitualTranslation(dx: -56, dy: 1))).isEmpty)
    #expect(reducer.reduce(.pointerUp(sequenceID: exactRelockSequence, monotonicTimeMilliseconds: 240, translation: RitualTranslation(dx: -56, dy: 1))).isEmpty)
    #expect(reducer.state.phase == .locked)
}

@Test
func verticalDominantUnlockMoveCancelsTheSequence() {
    let sequence = UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!
    var reducer = makeReducer()

    _ = reducer.reduce(.pointerDown(sequenceID: sequence, monotonicTimeMilliseconds: 0))
    #expect(reducer.state.phase == .unlocking)
    #expect(reducer.reduce(.pointerMove(
        sequenceID: sequence,
        monotonicTimeMilliseconds: 20,
        translation: RitualTranslation(dx: 20, dy: 30)
    )).isEmpty)
    #expect(reducer.state.phase == .locked)
    #expect(reducer.state.activeSequenceID == nil)
    #expect(reducer.state.ringTurnDegrees == 0)

    _ = reducer.reduce(.pointerMove(
        sequenceID: sequence,
        monotonicTimeMilliseconds: 40,
        translation: RitualTranslation(dx: 56, dy: 0)
    ))
    _ = reducer.reduce(.pointerUp(
        sequenceID: sequence,
        monotonicTimeMilliseconds: 60,
        translation: RitualTranslation(dx: 56, dy: 0)
    ))
    #expect(reducer.state.phase == .locked)
}

@Test
func relockCommitPreservesFinalReleaseDirectionUntilNextPointerDown() {
    var reducer = makeReadyReducer()
    let sequence = UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!

    _ = reducer.reduce(.pointerDown(sequenceID: sequence, monotonicTimeMilliseconds: 0))
    _ = reducer.reduce(.pointerMove(
        sequenceID: sequence,
        monotonicTimeMilliseconds: 20,
        translation: RitualTranslation(dx: 20, dy: 0)
    ))
    #expect(reducer.state.phase == .relocking)
    _ = reducer.reduce(.pointerUp(
        sequenceID: sequence,
        monotonicTimeMilliseconds: 40,
        translation: RitualTranslation(dx: -56, dy: 0)
    ))
    #expect(reducer.state.phase == .locked)
    #expect(reducer.state.ringTurnDegrees == -360)

    let next = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!
    _ = reducer.reduce(.pointerDown(sequenceID: next, monotonicTimeMilliseconds: 60))
    #expect(reducer.state.phase == .unlocking)
    #expect(reducer.state.ringTurnDegrees == 0)
}

@Test
func thresholdIsResponsiveButNeverBelow44AndHorizontalIntentIsDominant() {
    #expect(RitualReducer.threshold(forInteractionWidth: 200) == 44)
    #expect(RitualReducer.threshold(forInteractionWidth: 400) == 56)
    #expect(RitualReducer.horizontalIntent(dx: 10, dy: 8))
    #expect(!RitualReducer.horizontalIntent(dx: 10, dy: 9))
    #expect(RitualReducer.horizontalIntent(dx: -10, dy: 8))
}

@Test
func newPointerSequenceWaits120MillisecondsBeforeHoldingAndStartsOnlyOnce() {
    let sequence = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!
    var reducer = makeReadyReducer()

    #expect(reducer.reduce(.pointerDown(sequenceID: sequence, monotonicTimeMilliseconds: 100)).isEmpty)
    #expect(reducer.state.phase == .holdPending)
    #expect(reducer.reduce(.advance(sequenceID: sequence, monotonicTimeMilliseconds: 219)).isEmpty)
    #expect(reducer.state.phase == .holdPending)

    let effects = reducer.reduce(.advance(sequenceID: sequence, monotonicTimeMilliseconds: 220))
    #expect(reducer.state.phase == .holding)
    #expect(effects.filter { $0 == .startCue }.count == 1)
    #expect(reducer.reduce(.advance(sequenceID: sequence, monotonicTimeMilliseconds: 220)).isEmpty)
}

@Test
func firstMoveAtTheHoldDeadlineEmitsTheStartCueAndReusedSequenceCannotRestart() {
    let sequence = UUID(uuidString: "12121212-1212-1212-1212-121212121212")!
    var reducer = makeReadyReducer()

    _ = reducer.reduce(.pointerDown(sequenceID: sequence, monotonicTimeMilliseconds: 40))
    let effects = reducer.reduce(.pointerMove(
        sequenceID: sequence,
        monotonicTimeMilliseconds: 160,
        translation: .zero
    ))
    #expect(reducer.state.phase == .holding)
    #expect(effects.filter { $0 == .startCue }.count == 1)
    _ = reducer.reduce(.pointerUp(
        sequenceID: sequence,
        monotonicTimeMilliseconds: 200,
        translation: .zero
    ))
    #expect(reducer.state.phase == .paused)

    #expect(reducer.reduce(.pointerDown(sequenceID: sequence, monotonicTimeMilliseconds: 300)).isEmpty)
    #expect(reducer.state.phase == .paused)
}

@Test
func releaseAppliesElapsedTimeThenPausesAndResumeUsesAFreshPointerSequence() {
    let first = UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!
    let second = UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!
    var reducer = makeReadyReducer()

    _ = reducer.reduce(.pointerDown(sequenceID: first, monotonicTimeMilliseconds: 20))
    _ = reducer.reduce(.advance(sequenceID: first, monotonicTimeMilliseconds: 140))
    let advanceEffects = reducer.reduce(.advance(sequenceID: first, monotonicTimeMilliseconds: 680))
    #expect(reducer.state.phase == .holding)
    #expect(reducer.state.progress > 0.29)
    let releaseEffects = reducer.reduce(.pointerUp(
        sequenceID: first,
        monotonicTimeMilliseconds: 680,
        translation: .zero
    ))
    #expect(reducer.state.phase == .paused)
    #expect(reducer.state.progress == 0.3)
    #expect((advanceEffects + releaseEffects).filter { $0.isProgressCue }.count == 1)

    _ = reducer.reduce(.pointerDown(sequenceID: second, monotonicTimeMilliseconds: 1000))
    _ = reducer.reduce(.advance(sequenceID: second, monotonicTimeMilliseconds: 1120))
    #expect(reducer.state.phase == .holding)
    #expect(reducer.state.progress == 0.3)
    #expect(reducer.reduce(.advance(sequenceID: first, monotonicTimeMilliseconds: 2000)).isEmpty)
}

@Test
func verticalDominantMoveCancelsPendingHoldWithoutCreatingASession() {
    let sequence = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF")!
    var reducer = makeReadyReducer()

    _ = reducer.reduce(.pointerDown(sequenceID: sequence, monotonicTimeMilliseconds: 0))
    _ = reducer.reduce(.pointerMove(
        sequenceID: sequence,
        monotonicTimeMilliseconds: 40,
        translation: RitualTranslation(dx: 1, dy: 9)
    ))

    #expect(reducer.state.phase == .ready)
    #expect(reducer.state.sessionID == nil)
    #expect(reducer.state.interruptedCount == 0)
}

@Test
func backgroundAtOrAfterHoldDeadlineAppliesElapsedTimeBeforePausing() {
    let sequence = UUID(uuidString: "13131313-1313-1313-1313-131313131313")!
    var reducer = makeReadyReducer()

    _ = reducer.reduce(.pointerDown(sequenceID: sequence, monotonicTimeMilliseconds: 40))
    let effects = reducer.reduce(.background(sequenceID: sequence, monotonicTimeMilliseconds: 160))

    #expect(reducer.state.phase == .paused)
    #expect(reducer.state.progress == 0)
    #expect(reducer.state.interruptedCount == 1)
    #expect(effects.filter { $0 == .startCue }.count == 1)
    #expect(effects.filter { $0.isProgressCue }.isEmpty)
}

@Test
func terminationEventsAtAndBeyondDurationPauseWithoutCompletionOrPersistence() {
    let terminationEvents: [(String, (inout RitualReducer, UUID, Int64) -> [RitualEffect])] = [
        ("pointerUp", { reducer, sequence, time in
            reducer.reduce(.pointerUp(sequenceID: sequence, monotonicTimeMilliseconds: time, translation: .zero))
        }),
        ("pointerCancel", { reducer, sequence, time in
            reducer.reduce(.pointerCancel(sequenceID: sequence, monotonicTimeMilliseconds: time))
        }),
        ("background", { reducer, sequence, time in
            reducer.reduce(.background(sequenceID: sequence, monotonicTimeMilliseconds: time))
        }),
        ("sceneInactive", { reducer, sequence, time in
            reducer.reduce(.sceneInactive(sequenceID: sequence, monotonicTimeMilliseconds: time))
        })
    ]

    for (name, terminate) in terminationEvents {
        for offset in [0, 1] {
            let sequence = UUID()
            var reducer = makeReadyReducer()
            _ = reducer.reduce(.pointerDown(sequenceID: sequence, monotonicTimeMilliseconds: 40))
            _ = reducer.reduce(.advance(sequenceID: sequence, monotonicTimeMilliseconds: 160))
            let terminationTime = Int64(160 + reducer.profile.durationMilliseconds + offset)
            let effects = terminate(&reducer, sequence, terminationTime)

            #expect(reducer.state.phase == .paused, "\(name) at +\(offset)ms must pause")
            #expect(reducer.state.progress == 1, "\(name) at +\(offset)ms preserves accrued progress")
            #expect(effects.filter { $0 == .completionCue }.isEmpty, "\(name) at +\(offset)ms emits no completion cue")
            #expect(effects.filter { $0.isPersistCompletion }.isEmpty, "\(name) at +\(offset)ms emits no persistence")
        }
    }
}

@Test
func onlyAFreshSequenceAdvanceCompletesAnExactlyElapsedPausedSession() {
    let original = UUID(uuidString: "18181818-1818-1818-1818-181818181818")!
    let resumed = UUID(uuidString: "19191919-1919-1919-1919-191919191919")!
    var reducer = makeReadyReducer()

    _ = reducer.reduce(.pointerDown(sequenceID: original, monotonicTimeMilliseconds: 40))
    _ = reducer.reduce(.advance(sequenceID: original, monotonicTimeMilliseconds: 160))
    let duration = Int64(reducer.profile.durationMilliseconds)
    _ = reducer.reduce(.pointerUp(
        sequenceID: original,
        monotonicTimeMilliseconds: 160 + duration,
        translation: .zero
    ))
    #expect(reducer.state.phase == .paused)
    #expect(reducer.reduce(.advance(sequenceID: original, monotonicTimeMilliseconds: 5000)).isEmpty)
    #expect(reducer.state.phase == .paused)

    _ = reducer.reduce(.pointerDown(sequenceID: resumed, monotonicTimeMilliseconds: 5000))
    let effects = reducer.reduce(.advance(sequenceID: resumed, monotonicTimeMilliseconds: 5120))
    #expect(reducer.state.phase == .saving)
    #expect(effects.filter { $0 == .completionCue }.count == 1)
    #expect(effects.filter { $0.isPersistCompletion }.count == 1)
}

@Test
func relockCancelPreservesPausedSessionButSuccessfulRelockDiscardsIt() {
    let first = UUID(uuidString: "14141414-1414-1414-1414-141414141414")!
    let second = UUID(uuidString: "15151515-1515-1515-1515-151515151515")!
    var reducer = makeReadyReducer()
    _ = reducer.reduce(.pointerDown(sequenceID: first, monotonicTimeMilliseconds: 40))
    _ = reducer.reduce(.advance(sequenceID: first, monotonicTimeMilliseconds: 160))
    _ = reducer.reduce(.advance(sequenceID: first, monotonicTimeMilliseconds: 520))
    _ = reducer.reduce(.pointerUp(sequenceID: first, monotonicTimeMilliseconds: 520, translation: .zero))
    let progress = reducer.state.progress
    let session = reducer.state.sessionID

    _ = reducer.reduce(.pointerDown(sequenceID: second, monotonicTimeMilliseconds: 600))
    _ = reducer.reduce(.pointerMove(
        sequenceID: second,
        monotonicTimeMilliseconds: 620,
        translation: RitualTranslation(dx: 9, dy: 0)
    ))
    _ = reducer.reduce(.pointerCancel(sequenceID: second, monotonicTimeMilliseconds: 630))
    #expect(reducer.state.phase == .paused)
    #expect(reducer.state.progress == progress)
    #expect(reducer.state.sessionID == session)

    let relock = UUID(uuidString: "16161616-1616-1616-1616-161616161616")!
    _ = reducer.reduce(.pointerDown(sequenceID: relock, monotonicTimeMilliseconds: 700))
    _ = reducer.reduce(.pointerMove(
        sequenceID: relock,
        monotonicTimeMilliseconds: 720,
        translation: RitualTranslation(dx: -56, dy: 0)
    ))
    _ = reducer.reduce(.pointerUp(
        sequenceID: relock,
        monotonicTimeMilliseconds: 730,
        translation: RitualTranslation(dx: -56, dy: 0)
    ))
    #expect(reducer.state.phase == .locked)
    #expect(reducer.state.progress == 0)
    #expect(reducer.state.sessionID == nil)
    #expect(reducer.state.interruptedCount == 0)
}

@Test
func ninetyNinePointNinePercentReleasePausesWithoutCompletion() {
    let sequence = UUID(uuidString: "17171717-1717-1717-1717-171717171717")!
    var reducer = makeReadyReducer()
    _ = reducer.reduce(.pointerDown(sequenceID: sequence, monotonicTimeMilliseconds: 40))
    _ = reducer.reduce(.advance(sequenceID: sequence, monotonicTimeMilliseconds: 160))
    let effects = reducer.reduce(.pointerUp(
        sequenceID: sequence,
        monotonicTimeMilliseconds: 1_958,
        translation: .zero
    ))

    #expect(reducer.state.phase == .paused)
    #expect(reducer.state.progress < 1)
    #expect(effects.filter { $0 == .completionCue }.isEmpty)
    #expect(effects.filter { $0.isPersistCompletion }.isEmpty)
}

@Test
func rollbackDoesNotDecreaseProgressAndOldSequenceCallbacksAreIgnored() {
    let sequence = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    var reducer = makeReadyReducer()

    _ = reducer.reduce(.pointerDown(sequenceID: sequence, monotonicTimeMilliseconds: 0))
    _ = reducer.reduce(.advance(sequenceID: sequence, monotonicTimeMilliseconds: 120))
    _ = reducer.reduce(.advance(sequenceID: sequence, monotonicTimeMilliseconds: 1000))
    let progress = reducer.state.progress
    #expect(progress > 0)
    #expect(reducer.reduce(.advance(sequenceID: sequence, monotonicTimeMilliseconds: 400)).isEmpty)
    #expect(reducer.state.progress == progress)

    let old = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
    #expect(reducer.reduce(.pointerCancel(sequenceID: old, monotonicTimeMilliseconds: 1200)).isEmpty)
    #expect(reducer.state.phase == .holding)
    #expect(reducer.state.progress == progress)
}

@Test
func completionEmitsOnePersistRequestAndCuesForEachIntensityThreshold() {
    for intensity in Intensity.allCases {
        let sequence = UUID()
        var reducer = makeReadyReducer(intensity: intensity)
        _ = reducer.reduce(.pointerDown(sequenceID: sequence, monotonicTimeMilliseconds: 100))
        let effects = reducer.reduce(.advance(
            sequenceID: sequence,
            monotonicTimeMilliseconds: Int64(reducer.profile.durationMilliseconds + 220)
        ))

        #expect(reducer.state.phase == .saving)
        #expect(effects.filter { $0.isProgressCue }.count == intensity.rawValue)
        #expect(effects.filter { $0 == .startCue }.count == 1)
        #expect(effects.filter { $0 == .completionCue }.count == 1)
        #expect(effects.filter { $0.isPersistCompletion }.count == 1)
        #expect(reducer.reduce(.pointerCancel(sequenceID: sequence, monotonicTimeMilliseconds: 9999)).isEmpty)
        #expect(reducer.state.phase == .saving)
    }
}

@Test
func saveFailureKeepsTheSameSessionForRetryAndSuccessWaitsForTheRecordingCallback() throws {
    let sequence = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
    let retrySequence = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
    var reducer = makeReadyReducer()
    _ = reducer.reduce(.pointerDown(sequenceID: sequence, monotonicTimeMilliseconds: 0))
    let completion = reducer.reduce(.advance(
        sequenceID: sequence,
        monotonicTimeMilliseconds: 2040
    ))
    let sessionID = try! #require(reducer.state.sessionID)
    #expect(completion.compactMap(\.completionSessionID) == [sessionID])
    #expect(reducer.state.phase == .saving)

    _ = reducer.reduce(.recordingFailed(
        sessionID: sessionID,
        sequenceID: sequence,
        monotonicTimeMilliseconds: 2000
    ))
    #expect(reducer.state.phase == .saveFailed)
    #expect(reducer.state.sessionID == sessionID)

    let retryEffects = reducer.reduce(.retryRecording(
        sessionID: sessionID,
        sequenceID: retrySequence,
        monotonicTimeMilliseconds: 2100
    ))
    #expect(reducer.state.phase == .saving)
    #expect(retryEffects.compactMap(\.completionSessionID) == [sessionID])
    _ = reducer.reduce(.recordingSucceeded(
        sessionID: sessionID,
        sequenceID: retrySequence,
        monotonicTimeMilliseconds: 2200
    ))
    #expect(reducer.state.phase == .completed)
    #expect(reducer.reduce(.recordingSucceeded(
        sessionID: sessionID,
        sequenceID: retrySequence,
        monotonicTimeMilliseconds: 2300
    )).isEmpty)
    _ = reducer.reduce(.reset(sequenceID: UUID(), monotonicTimeMilliseconds: 2400))
    #expect(reducer.state.phase == .locked)
}

@Test
func twentyInterruptionsAreCountedOnlyAfterHoldBeginsAndBackgroundPauses() {
    var reducer = makeReadyReducer()
    for index in 0..<20 {
        let sequence = UUID()
        let base = Int64(index * 300 + 20)
        _ = reducer.reduce(.pointerDown(sequenceID: sequence, monotonicTimeMilliseconds: base))
        _ = reducer.reduce(.advance(sequenceID: sequence, monotonicTimeMilliseconds: base + 120))
        _ = reducer.reduce(.pointerUp(
            sequenceID: sequence,
            monotonicTimeMilliseconds: base + 120,
            translation: .zero
        ))
    }
    #expect(reducer.state.phase == .paused)
    #expect(reducer.state.interruptedCount == 20)

    let final = UUID()
    _ = reducer.reduce(.pointerDown(sequenceID: final, monotonicTimeMilliseconds: 6020))
    _ = reducer.reduce(.advance(sequenceID: final, monotonicTimeMilliseconds: 6140))
    let effects = reducer.reduce(.background(sequenceID: final, monotonicTimeMilliseconds: 6200))
    #expect(effects.isEmpty)
    #expect(reducer.state.phase == .paused)
    #expect(reducer.state.interruptedCount == 21)
}

private func makeReducer(
    intensity: Intensity = .three,
    uuid: UUID = UUID(uuidString: "99999999-9999-9999-9999-999999999999")!
) -> RitualReducer {
    RitualReducer(
        configuration: RitualConfiguration(
            intensity: intensity,
            interactionWidth: 320,
            source: .app,
            startedAtUTC: Date(timeIntervalSince1970: 1_757_000_000)
        ),
        uuidGenerator: FixedUUIDGenerator(id: uuid)
    )
}

private func makeReadyReducer(intensity: Intensity = .three) -> RitualReducer {
    let sequence = UUID(uuidString: "ABABABAB-ABAB-ABAB-ABAB-ABABABABABAB")!
    var reducer = makeReducer(intensity: intensity)
    _ = reducer.reduce(.pointerDown(sequenceID: sequence, monotonicTimeMilliseconds: 0))
    _ = reducer.reduce(.pointerUp(
        sequenceID: sequence,
        monotonicTimeMilliseconds: 20,
        translation: RitualTranslation(dx: 56, dy: 0)
    ))
    return reducer
}

private struct FixedUUIDGenerator: UUIDGenerator {
    let id: UUID

    func makeUUID() -> UUID { id }
}
