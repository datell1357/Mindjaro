import Foundation
import MaeumjaroDomain
import XCTest
@testable import Maeumjaro

@MainActor
final class RitualViewModelTests: XCTestCase {
    func testAccessibilityContentIsNonEmptyForInitialState() {
        let model = RitualViewModel(configuration: RitualConfiguration(intensity: .three), recorder: FakeCompletionRecorder(), phraseID: "phrase.test", phraseText: "테스트 문구")
        let content = RitualAccessibilityContent.forState(model.state)
        XCTAssertFalse(content.label.isEmpty)
        XCTAssertFalse(content.value.isEmpty)
        XCTAssertFalse(content.hint.isEmpty)
    }

    func testViewModelUsesSchema5LiquidMath() {
        XCTAssertEqual(PenAssetContract.schemaVersion, 5)
        XCTAssertEqual(PenAssetContract.liquidTopOffset(initialFill: 0.6, progress: 0.5), 289.8, accuracy: 1e-9)
        XCTAssertEqual(PenAssetContract.remainingLiquidHeight(initialFill: 0.6, progress: 0.5), 124.2, accuracy: 1e-9)
    }

    func testRingPresentationNeverMirrorsFaceAtHalfTurns() {
        XCTAssertEqual(PenAssetContract.ringPresentation(progress: 0, direction: .right).face, .source)
        XCTAssertEqual(PenAssetContract.ringPresentation(progress: 0.5, direction: .right).face, .destination)
        XCTAssertEqual(PenAssetContract.ringPresentation(progress: 1, direction: .right).rotationDegrees, 0)
        XCTAssertEqual(PenAssetContract.ringPresentation(progress: 1, direction: .left).rotationDegrees, 0)
    }

    func testCompletionRecordingRequestKeepsSessionIdentity() throws {
        let id = UUID()
        let event = InjectionEvent(id: id, startedAtUTC: .distantPast, completedAtUTC: .distantFuture, createdAtUTC: .distantFuture, eventLocalDate: "2026-09-05", timezoneOffsetMinutes: 540, intensity: .three, source: .app, phraseID: "neutral", animationDurationMilliseconds: 1800, interruptedCount: 0, appVersion: "1")
        let request = try CompletionRecordingRequest(sessionID: id, event: event).validated()
        XCTAssertEqual(request.idempotencyKey, id)
        XCTAssertTrue(request.isIdempotencyConsistent)
    }

    func testHostedBackgroundAt99PercentPausesWithoutRecordingAndStaleTicksCannotComplete() {
        let clock = TestRitualMonotonicClock()
        let recorder = FakeCompletionRecorder()
        let model = RitualViewModel(
            configuration: RitualConfiguration(intensity: .five),
            recorder: recorder,
            clock: clock,
            phraseID: "phrase.test",
            phraseText: "테스트 문구"
        )
        let unlockSequence = UUID()
        model.pointerDown(sequenceID: unlockSequence)
        model.pointerUp(sequenceID: unlockSequence, translation: CGSize(width: 56, height: 0))
        XCTAssertEqual(model.state.phase, .ready)

        let firstSequence = UUID()
        model.pointerDown(sequenceID: firstSequence)
        clock.advance(to: 120)
        model.tick(sequenceID: firstSequence)
        XCTAssertEqual(model.state.phase, .holding)

        let ninetyNinePercentElapsed: Int64 = 3_168
        clock.advance(to: 120 + ninetyNinePercentElapsed)
        model.background()
        XCTAssertEqual(model.state.phase, .paused)
        XCTAssertEqual(model.state.progress, 0.99, accuracy: 0.000001)
        XCTAssertEqual(recorder.calls, 0)

        clock.advance(to: 10_000)
        model.tick(sequenceID: firstSequence)
        model.tick(sequenceID: firstSequence)
        XCTAssertEqual(model.state.phase, .paused)
        XCTAssertEqual(recorder.calls, 0)
    }

    func testHostedBackgroundAt99PercentResumesWithFreshSequenceAndRecordsExactlyOnce() async {
        let clock = TestRitualMonotonicClock()
        let recorder = FakeCompletionRecorder()
        let model = RitualViewModel(
            configuration: RitualConfiguration(intensity: .five),
            recorder: recorder,
            clock: clock,
            phraseID: "phrase.test",
            phraseText: "테스트 문구"
        )
        let unlockSequence = UUID()
        model.pointerDown(sequenceID: unlockSequence)
        model.pointerUp(sequenceID: unlockSequence, translation: CGSize(width: 56, height: 0))

        let firstSequence = UUID()
        model.pointerDown(sequenceID: firstSequence)
        clock.advance(to: 120)
        model.tick(sequenceID: firstSequence)
        clock.advance(to: 3_288)
        model.background()
        XCTAssertEqual(model.state.phase, .paused)
        XCTAssertEqual(model.state.progress, 0.99, accuracy: 0.000001)

        let resumedSequence = UUID()
        clock.advance(to: 3_408)
        model.pointerDown(sequenceID: resumedSequence)
        clock.advance(to: 3_528)
        model.tick(sequenceID: resumedSequence)
        XCTAssertEqual(model.state.phase, .holding)

        clock.advance(to: 3_560)
        model.tick(sequenceID: resumedSequence)
        XCTAssertEqual(model.state.phase, .saving)
        XCTAssertEqual(recorder.calls, 0)

        for _ in 0..<40 where model.state.phase != .completed {
            await Task.yield()
        }
        XCTAssertEqual(model.state.phase, .completed)
        XCTAssertEqual(recorder.calls, 1)
    }
}

@MainActor private final class FakeCompletionRecorder: CompletionRecording {
    var calls = 0
    func recordCompletion(_ request: CompletionRecordingRequest) async throws -> CompletionRecordingOutcome { calls += 1; return .inserted }
}

private final class TestRitualMonotonicClock: RitualMonotonicClock, @unchecked Sendable {
    private let lock = NSLock()
    private var value: Int64 = 0

    var nowMilliseconds: Int64 {
        lock.lock(); defer { lock.unlock() }
        return value
    }

    func advance(to milliseconds: Int64) {
        lock.lock(); defer { lock.unlock() }
        value = milliseconds
    }
}
