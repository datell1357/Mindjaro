import SwiftUI
import MaeumjaroDomain

struct InjectionCanvas: View {
    let state: RitualState
    let initialFill: Double
    let reduceMotion: Bool
    @State private var visualRingTurn: Double = 0
    @State private var settlingPhase: RitualPhase?

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 1024, proxy.size.height / 1536)
            let size = CGSize(width: 1024 * scale, height: 1536 * scale)
            ZStack {
                readyBase(size: size, scale: scale)
                Image("PenWindowEmpty").resizable()
                    .frame(width: 126 * scale, height: 414 * scale)
                    .position(x: 512 * scale, y: 857 * scale)
                LiquidMask(progress: state.progress, initialFill: initialFill, reduceMotion: reduceMotion)
                    .frame(width: 126 * scale, height: 414 * scale)
                    .position(x: 512 * scale, y: 857 * scale)
                ring(scale: scale)
            }.frame(width: size.width, height: size.height)
        }
        .aspectRatio(1024.0 / 1536.0, contentMode: .fit)
        .onAppear { visualRingTurn = state.ringTurnDegrees }
        .onChange(of: state) { oldState, newState in
            let isRelease = oldState.activeSequenceID != nil && newState.activeSequenceID == nil
            let target = newState.ringTurnDegrees
            if isRelease && !reduceMotion && (oldState.phase == .unlocking || oldState.phase == .relocking) {
                settlingPhase = oldState.phase
                withAnimation(.timingCurve(0.22, 1, 0.36, 1, duration: 0.26)) {
                    visualRingTurn = target
                }
            } else {
                // Pointer tracking remains direct; reduced motion commits immediately.
                settlingPhase = nil
                visualRingTurn = isRelease ? target : newState.ringTurnDegrees
            }
        }
    }

    private func readyBase(size: CGSize, scale: CGFloat) -> some View {
        Image("PenReady").resizable().frame(width: size.width, height: size.height).mask {
            Canvas { context, canvasSize in
                var path = Path(CGRect(origin: .zero, size: canvasSize))
                path.addRect(CGRect(x: 362 * scale, y: 136 * scale, width: 300 * scale, height: 112 * scale))
                context.fill(path, with: .color(.white), style: FillStyle(eoFill: true))
            }
        }
    }

    private func ring(scale: CGFloat) -> some View {
        let presentationPhase = reduceMotion ? state.phase : (settlingPhase ?? state.phase)
        return RingVisual(turnDegrees: reduceMotion ? 0 : visualRingTurn, phase: presentationPhase, scale: scale, reduceMotion: reduceMotion)
            .position(x: 512 * scale, y: 192 * scale)
    }
}

private struct RingVisual: View, Animatable {
    nonisolated var turnDegrees: Double
    let phase: RitualPhase
    let scale: CGFloat
    let reduceMotion: Bool
    nonisolated var animatableData: Double {
        get { turnDegrees }
        set { turnDegrees = newValue }
    }

    var body: some View {
        let presentation = InjectionRingPresentation.presentation(phase: phase, turnDegrees: turnDegrees, reduceMotion: reduceMotion)
        Image(presentation.face.assetName).resizable()
            .frame(width: 300 * scale, height: 112 * scale)
            .rotation3DEffect(.degrees(presentation.localRotationDegrees), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
    }
}

enum InjectionRingPresentation {
    static func presentation(phase: RitualPhase, turnDegrees: Double, reduceMotion: Bool) -> (face: PenRingFace, localRotationDegrees: Double) {
        if reduceMotion { return (committedFace(for: phase), 0) }
        let absolute = abs(turnDegrees)
        let face: PenRingFace
        switch phase {
        case .locked:
            // A relock commit is represented by the view's transient ±360 turn,
            // while an ordinary locked drag only reaches ±180.
            face = absolute >= 270 ? .source : (absolute >= 90 ? .destination : .source)
        case .unlocking: face = absolute >= 90 ? .destination : .source
        case .relocking: face = absolute >= 270 ? .source : .destination
        case .ready, .holdPending, .holding, .paused, .saving, .saveFailed, .completed: face = .destination
        }
        return (face, localRotation(face: face, turnDegrees: turnDegrees))
    }

    /// Keep each raster face upright while preserving the canonical cylinder
    /// turn: source is 0/360, destination is 180 (with signed direction).
    static func localRotation(face: PenRingFace, turnDegrees: Double) -> Double {
        guard face == .destination else { return turnDegrees }
        return turnDegrees - (turnDegrees < 0 ? -180 : 180)
    }

    private static func committedFace(for phase: RitualPhase) -> PenRingFace {
        switch phase {
        case .locked, .unlocking: .source
        case .ready, .holdPending, .holding, .paused, .relocking, .saving, .saveFailed, .completed: .destination
        }
    }
}

private extension PenRingFace {
    var assetName: String { self == .source ? "PenRingLocked" : "PenRingReady" }
}
