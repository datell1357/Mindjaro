import SwiftUI
import MaeumjaroDomain

struct RitualView: View {
    @State private var model: RitualViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.dismiss) private var dismiss
    @State private var sequenceID: UUID?
    @State private var didBegin = false
    @GestureState private var gestureActive = false
    let haptics: any RitualHapticEngine
    let sound: any RitualSoundEngine
    let reducedMotion: Bool
    let palette: ThemePalette

    init(model: RitualViewModel, palette: ThemePalette = .quietIvory, haptics: any RitualHapticEngine = SystemRitualHapticEngine(), sound: any RitualSoundEngine = SystemRitualSoundEngine(), reducedMotion: Bool = false) {
        _model = State(initialValue: model); self.palette = palette; self.haptics = haptics; self.sound = sound; self.reducedMotion = reducedMotion
    }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
            TimelineTickContent(model: model, date: context.date) { content }
        }
            .background(palette.background.color.ignoresSafeArea())
            .onChange(of: scenePhase) { _, phase in if phase != .active { model.background(); sequenceID = nil; didBegin = false } }
            .onChange(of: model.lastEffects) { _, effects in
                for effect in effects {
                    switch effect { case .startCue: haptics.start(); case let .progressCue(index, _): haptics.progress(index: index); case .completionCue: haptics.completion(); sound.completion(); case .completed: break; case .persistCompletion, .recordingFailed: break }
                }
            }
            .onChange(of: gestureActive) { _, active in
                guard !active, didBegin, let id = sequenceID else { return }
                model.pointerCancel(sequenceID: id)
                sequenceID = nil
                didBegin = false
            }
            .interactiveDismissDisabled(model.state.phase == .saving)
            .onDisappear {
                model.reset()
                sequenceID = nil
                didBegin = false
            }
    }
    @ViewBuilder private var content: some View {
        if dynamicTypeSize.isAccessibilitySize {
            ScrollView { ritualContent }
        } else {
            ritualContent
        }
    }
    @ViewBuilder private var ritualContent: some View {
        let state = model.state
        VStack(spacing: 16) {
            HStack {
                Spacer()
                Button("닫기", action: close)
                    .foregroundStyle(palette.ink.color)
                    .disabled(state.phase == .saving)
                    .frame(minWidth: DesignTokens.minimumTouchTarget, minHeight: DesignTokens.minimumTouchTarget)
                    .tint(palette.accent.color)
                    .accessibilityIdentifier("ritual-close")
            }
            Text(LocalizedStringKey(state.phase == .completed ? "완료" : "마음 정리 의식")).font(.title).fontWeight(.bold).foregroundStyle(palette.ink.color)
            Text(model.accessibility.hint).font(.body).foregroundStyle(palette.secondaryInk.color).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("ritual-hint")
            Text(model.phraseText).font(.body).foregroundStyle(palette.ink.color).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            InjectionCanvas(state: state, initialFill: model.reducer.profile.initialFill, reduceMotion: reducedMotion || systemReduceMotion)
                .frame(maxWidth: 360).contentShape(Rectangle()).gesture(gesture)
                .accessibilityElement(children: .ignore).accessibilityLabel(model.accessibility.label).accessibilityValue(model.accessibility.value).accessibilityHint(model.accessibility.hint)
                .accessibilityAction(named: "잠금 풀기", model.assistiveUnlock)
                .accessibilityAction(named: "시작 또는 재개", model.assistiveStart)
                .accessibilityAction(named: "일시정지", model.assistivePause)
                .accessibilityIdentifier("ritual-canvas")
            Text(model.accessibility.value).font(.body).foregroundStyle(palette.ink.color).monospacedDigit().accessibilityIdentifier("ritual-progress")
            if state.phase == .saveFailed { Button("기록 다시 시도", action: model.retry).frame(minHeight: DesignTokens.minimumTouchTarget).tint(palette.accent.color) }
            if state.phase == .completed, let date = model.completionDateValue { RitualCompletionView(intensity: state.intensity, completedAt: date, palette: palette, onRestart: model.reset, onRecords: { dismiss() }) }
        }.padding().background(palette.background.color).contentShape(Rectangle())
    }
    private func close() {
        guard model.state.phase != .saving else { return }
        model.reset()
        sequenceID = nil
        didBegin = false
        dismiss()
    }
    private var gesture: some Gesture { DragGesture(minimumDistance: 0).updating($gestureActive) { _, active, _ in active = true }.onChanged { value in if !didBegin { let id = UUID(); sequenceID = id; didBegin = true; model.pointerDown(sequenceID: id) }; if let id = sequenceID { model.pointerMove(sequenceID: id, translation: value.translation) } }.onEnded { value in if let id = sequenceID { model.pointerUp(sequenceID: id, translation: value.translation) }; sequenceID = nil; didBegin = false } }
}

private struct TimelineTickContent<Content: View>: View {
    let model: RitualViewModel
    let date: Date
    @ViewBuilder let content: () -> Content
    var body: some View {
        content().onChange(of: date) { _, _ in model.tick(sequenceID: model.state.activeSequenceID) }
    }
}
