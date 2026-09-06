import Foundation
import MaeumjaroDomain
import Observation

protocol RitualMonotonicClock: Sendable { var nowMilliseconds: Int64 { get } }
struct SystemRitualMonotonicClock: RitualMonotonicClock {
    private let origin: ContinuousClock.Instant
    init(clock: ContinuousClock = ContinuousClock()) { origin = clock.now }
    var nowMilliseconds: Int64 {
        let duration = origin.duration(to: ContinuousClock().now).components
        return duration.seconds * 1_000 + duration.attoseconds / 1_000_000_000_000_000
    }
}

@MainActor @Observable
final class RitualViewModel {
    private(set) var reducer: RitualReducer
    private let recorder: any CompletionRecording
    private let clock: any RitualMonotonicClock
    let phraseID: String
    let phraseText: String
    let completionDate: () -> Date
    private(set) var lastEffects: [RitualEffect] = []
    private(set) var completionDateValue: Date?
    private var completionRequest: CompletionRecordingRequest?

    init(
        configuration: RitualConfiguration,
        recorder: any CompletionRecording,
        clock: any RitualMonotonicClock = SystemRitualMonotonicClock(),
        uuidGenerator: any UUIDGenerator = SystemUUIDGenerator(),
        phraseID: String = "",
        phraseText: String = "",
        completionDate: @escaping () -> Date = Date.init
    ) {
        reducer = RitualReducer(configuration: configuration, uuidGenerator: uuidGenerator)
        self.recorder = recorder; self.clock = clock; self.phraseID = phraseID; self.phraseText = phraseText; self.completionDate = completionDate
    }

    var state: RitualState { reducer.state }
    var accessibility: RitualAccessibilityContent { .forState(state) }
    func pointerDown(sequenceID: UUID) { reduce(.pointerDown(sequenceID: sequenceID, monotonicTimeMilliseconds: clock.nowMilliseconds)) }
    func pointerMove(sequenceID: UUID, translation: CGSize) { reduce(.pointerMove(sequenceID: sequenceID, monotonicTimeMilliseconds: clock.nowMilliseconds, translation: .init(dx: translation.width, dy: translation.height))) }
    func pointerUp(sequenceID: UUID, translation: CGSize) { reduce(.pointerUp(sequenceID: sequenceID, monotonicTimeMilliseconds: clock.nowMilliseconds, translation: .init(dx: translation.width, dy: translation.height))) }
    func pointerCancel(sequenceID: UUID) { reduce(.pointerCancel(sequenceID: sequenceID, monotonicTimeMilliseconds: clock.nowMilliseconds)) }
    func tick(sequenceID: UUID?) { guard let id = sequenceID else { return }; reduce(.advance(sequenceID: id, monotonicTimeMilliseconds: clock.nowMilliseconds)) }
    func background() { if let id = state.activeSequenceID { reduce(.background(sequenceID: id, monotonicTimeMilliseconds: clock.nowMilliseconds)) } }
    func assistiveStart() { let id = UUID(); reduce(.assistiveStart(sequenceID: id, monotonicTimeMilliseconds: clock.nowMilliseconds)) }
    func assistiveUnlock() {
        let id = UUID(); let now = clock.nowMilliseconds
        reduce(.pointerDown(sequenceID: id, monotonicTimeMilliseconds: now))
        reduce(.pointerUp(sequenceID: id, monotonicTimeMilliseconds: now, translation: RitualTranslation(dx: 56, dy: 0)))
    }
    func assistivePause() { if let id = state.activeSequenceID { reduce(.assistivePause(sequenceID: id, monotonicTimeMilliseconds: clock.nowMilliseconds)) } }
    func retry() { guard let session = state.sessionID else { return }; reduce(.retryRecording(sessionID: session, sequenceID: UUID(), monotonicTimeMilliseconds: clock.nowMilliseconds)) }
    func reset() {
        guard state.phase != .saving else { return }
        reduce(.reset(sequenceID: UUID(), monotonicTimeMilliseconds: clock.nowMilliseconds))
        completionRequest = nil
        completionDateValue = nil
    }

    private func reduce(_ action: RitualAction) {
        let effects = reducer.reduce(action); lastEffects = effects
        for effect in effects { handle(effect) }
    }
    private func handle(_ effect: RitualEffect) {
        switch effect {
        case let .persistCompletion(seed):
            let sequence = state.activeSequenceID ?? UUID()
            if completionRequest == nil {
                let now = completionDate()
                completionDateValue = now
                var calendar = Calendar.current
                calendar.timeZone = .current
                let components = calendar.dateComponents([.year, .month, .day], from: now)
                let localDate = String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
                let event = InjectionEvent(id: seed.sessionID, startedAtUTC: seed.startedAtUTC ?? now, completedAtUTC: now, createdAtUTC: now, eventLocalDate: localDate, timezoneOffsetMinutes: TimeZone.current.secondsFromGMT(for: now) / 60, intensity: seed.intensity, source: seed.source, phraseID: phraseID, animationDurationMilliseconds: seed.animationDurationMilliseconds, interruptedCount: seed.interruptedCount, appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0")
                completionRequest = CompletionRecordingRequest(sessionID: seed.sessionID, event: event)
            }
            guard let request = completionRequest else { return }
            Task { [weak self] in
                guard let self else { return }
                do {
                    switch try await recorder.recordCompletion(request) {
                    case .inserted: reduce(.recordingSucceeded(sessionID: seed.sessionID, sequenceID: sequence, monotonicTimeMilliseconds: clock.nowMilliseconds))
                    case .alreadyRecorded: reduce(.recordingAlreadyRecorded(sessionID: seed.sessionID, sequenceID: sequence, monotonicTimeMilliseconds: clock.nowMilliseconds))
                    }
                } catch { reduce(.recordingFailed(sessionID: seed.sessionID, sequenceID: sequence, monotonicTimeMilliseconds: clock.nowMilliseconds)) }
            }
        case .startCue, .progressCue, .completionCue, .recordingFailed, .completed: break
        }
    }
}
