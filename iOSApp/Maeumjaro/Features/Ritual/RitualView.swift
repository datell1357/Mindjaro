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
    let onRecords: () -> Void

    init(model: RitualViewModel, palette: ThemePalette = .quietIvory, haptics: any RitualHapticEngine = SystemRitualHapticEngine(), sound: any RitualSoundEngine = SystemRitualSoundEngine(), reducedMotion: Bool = false, onRecords: @escaping () -> Void = {}) {
        _model = State(initialValue: model); self.palette = palette; self.haptics = haptics; self.sound = sound; self.reducedMotion = reducedMotion
        self.onRecords = onRecords
    }
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { context in
            TimelineTickContent(model: model, date: context.date) { content }
        }
            .background(palette.background.color.ignoresSafeArea())
            .onChange(of: scenePhase) { _, phase in if phase != .active { model.background(); sequenceID = nil; didBegin = false } }
            .onChange(of: model.lastEffects) { _, effects in
                for effect in effects {
                    switch effect { case .startCue: haptics.start(); case let .progressCue(index, _): haptics.progress(index: index); case .completionCue: haptics.completion(); sound.completion(); case .completed: break; case .persistCompletion, .recordingFailed: break }
                }
            }
            .interactiveDismissDisabled(model.state.phase == .saving)
            .onChange(of: gestureActive) { _, active in
                guard !active, didBegin, let id = sequenceID else { return }
                model.pointerCancel(sequenceID: id)
                sequenceID = nil
                didBegin = false
            }
            .onDisappear {
                model.reset()
                sequenceID = nil
                didBegin = false
            }
    }
    @ViewBuilder private var content: some View {
        GeometryReader { proxy in
            if model.state.phase == .completed || dynamicTypeSize.isAccessibilitySize {
                ScrollView { ritualContent(penHeight: max(240, proxy.size.height - 140)) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ritualContent(penHeight: max(0, proxy.size.height - 140)).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
    @ViewBuilder private func ritualContent(penHeight: CGFloat) -> some View {
        let state = model.state
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: DesignTokens.minimumTouchTarget, height: DesignTokens.minimumTouchTarget)
                }
                .accessibilityLabel("닫기")
                    .foregroundStyle(palette.ink.color)
                    .disabled(state.phase == .saving)
                    .tint(palette.accent.color)
                    .accessibilityIdentifier("ritual-close")
            }
            Spacer(minLength: 8)
            InjectionCanvas(state: state, initialFill: model.reducer.profile.initialFill, reduceMotion: reducedMotion || systemReduceMotion)
                .frame(height: penHeight)
                .contentShape(Rectangle())
                .gesture(gesture)
                .accessibilityElement(children: .ignore).accessibilityLabel(model.accessibility.label).accessibilityValue("\(model.accessibility.value) · \(phaseAccessibilityLabel(state.phase))").accessibilityHint(model.accessibility.hint)
                .accessibilityAction(named: "잠금 풀기", model.assistiveUnlock)
                .accessibilityAction(named: "시작 또는 재개", model.assistiveStart)
                .accessibilityAction(named: "일시정지", model.assistivePause)
                .accessibilityIdentifier("ritual-canvas")
            VStack(spacing: 10) {
                ProgressView(value: state.progress)
                    .progressViewStyle(.linear)
                    .tint(palette.accent.color)
                    .frame(height: 2)
                    .accessibilityLabel("진행률")
                    .accessibilityValue(model.accessibility.value)
                    .accessibilityHint(model.accessibility.hint)
                    .accessibilityIdentifier("ritual-progress")
                Image(systemName: "arrow.left.and.right")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(palette.secondaryInk.color.opacity(state.phase == .locked || state.phase == .relocking ? 0.8 : 0))
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: 240)
            Spacer(minLength: 8)
            if state.phase == .saveFailed { Button("기록 다시 시도", action: model.retry).frame(minHeight: DesignTokens.minimumTouchTarget).tint(palette.accent.color) }
            if state.phase == .completed, let date = model.completionDateValue { RitualCompletionView(intensity: state.intensity, completedAt: date, palette: palette, onRestart: model.reset, onRecords: onRecords) }
        }
        .padding(.horizontal, DesignTokens.spacing6)
        .padding(.vertical, DesignTokens.spacing4)
        .background(palette.background.color)
        .contentShape(Rectangle())
    }
    private func close() {
        guard model.state.phase != .saving else { return }
        model.reset()
        sequenceID = nil
        didBegin = false
        dismiss()
    }

    private func phaseAccessibilityLabel(_ phase: RitualPhase) -> String {
        switch phase {
        case .locked: "잠금"
        case .unlocking: "잠금 해제 중"
        case .ready: "준비됨"
        case .holdPending: "시작 대기"
        case .holding: "진행 중"
        case .paused: "일시정지"
        case .relocking: "다시 잠그는 중"
        case .saving: "저장 중"
        case .saveFailed: "저장 실패"
        case .completed: "완료"
        }
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
