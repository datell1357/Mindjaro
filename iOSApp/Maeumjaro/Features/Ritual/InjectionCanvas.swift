import SwiftUI
import UIKit
import MaeumjaroDomain

struct InjectionCanvas: View {
    let state: RitualState
    let initialFill: Double
    let reduceMotion: Bool
    @State private var visualRingTurn: Double = 0
    @State private var settlingPhase: RitualPhase?

    var body: some View {
        GeometryReader { proxy in
            let scale = min(proxy.size.width / 300, proxy.size.height / 1536)
            let size = CGSize(width: 1024 * scale, height: 1536 * scale)
            ZStack {
                readyBase(size: size, scale: scale)
                Image("PenWindowEmpty").resizable()
                    .frame(width: 126 * scale, height: 414 * scale)
                    .position(x: 512 * scale, y: 857 * scale)
                LiquidMask(progress: state.progress, initialFill: initialFill, intensity: state.intensity, reduceMotion: reduceMotion)
                    .frame(width: 126 * scale, height: 414 * scale)
                    .position(x: 512 * scale, y: 857 * scale)
                ring(scale: scale)
            }.frame(width: size.width, height: size.height)
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
        }
        .aspectRatio(300.0 / 1536.0, contentMode: .fit)
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

struct RingVisual: View, Animatable {
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
        let projection = InjectionRingPresentation.cylinderProjection(face: presentation.face, turnDegrees: turnDegrees, reduceMotion: reduceMotion)
        CylindricalRingImage(face: presentation.face, turnDegrees: turnDegrees, projection: projection)
            .frame(width: 300 * scale, height: 112 * scale)
    }
}

/// Projects the original ring PNG as vertical strips around a cylinder. Each strip is
/// cropped from the source image, preserving the source alpha and exact endpoint pixels.
private struct CylindricalRingImage: View {
    let face: PenRingFace
    let turnDegrees: Double
    let projection: InjectionRingPresentation.CylinderProjection

    private static let stripCount = 300
    private static let cachedStrips: [PenRingFace: [CGImage]] = {
        Dictionary(uniqueKeysWithValues: [PenRingFace.source, .destination].map { face in
            let image = UIImage(named: face.assetName)!.cgImage!
            let width = CGFloat(image.width) / CGFloat(stripCount)
            let strips = (0..<stripCount).compactMap { index -> CGImage? in
                let x = CGFloat(index) * width
                return image.cropping(to: CGRect(x: x, y: 0, width: min(width, CGFloat(image.width) - x), height: CGFloat(image.height)).integral)
            }
            return (face, strips)
        })
    }()

    var body: some View {
        if projection.widthScale > 0.9999 && abs(projection.xOffset) < 0.001 {
            Image(face.assetName)
                .resizable()
        } else {
            Canvas { context, size in
                let turn = turnDegrees * .pi / 180
                let destinationWidth = size.width / CGFloat(Self.stripCount)
                for index in 0..<Self.stripCount {
                    let normalizedX = (CGFloat(index) + 0.5) / CGFloat(Self.stripCount) * 2 - 1
                    let surfaceAngle = asin(normalizedX)
                    let localAngle = surfaceAngle - turn
                    // The raster includes transparent rounded-edge pixels. Those are
                    // silhouette coverage, not a transparent patch on the cylinder.
                    // Extend the adjacent material at the hidden hemisphere seam;
                    // the stationary outer mask supplies the actual edge coverage.
                    let seam = min(1, max(0, (cos(localAngle) + 0.25) / 0.5))
                    let frontWeight = seam * seam * (3 - 2 * seam)
                    let rect = CGRect(x: CGFloat(index) * destinationWidth, y: 0, width: destinationWidth + 0.1, height: size.height)
                    // Blend only the icon-free edge material, never the lock marks.
                    // This joins the two baked lighting states without a hard seam.
                    for sourceFace in [PenRingFace.destination, .source] {
                        let opacity = sourceFace == .source ? frontWeight : 1
                        if opacity == 0 { continue }
                        let sourceNormalizedX = min(0.90, max(0.10, (sin(localAngle) * (sourceFace == .source ? 1 : -1) + 1) / 2))
                        let sourceIndex = min(Self.stripCount - 1, max(0, Int(sourceNormalizedX * CGFloat(Self.stripCount))))
                        guard let strip = Self.cachedStrips[sourceFace]?[sourceIndex] else { continue }
                        var stripContext = context
                        stripContext.opacity = opacity
                        stripContext.draw(Image(decorative: strip, scale: 1, orientation: .up), in: rect)
                    }
                }
            }
            .mask { Image("PenRingLocked").resizable() }
        }
    }
}

private extension PenRingFace {
    var assetName: String { self == .source ? "PenRingLocked" : "PenRingReady" }
}

enum InjectionRingPresentation {
    struct CylinderProjection {
        let xOffset: CGFloat
        let widthScale: CGFloat
        let sideLight: Double
        let opacity: Double
    }

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

    /// Preserve the canonical signed turn for callers and regression tests:
    /// source is 0/360, destination is 180 (with signed direction).
    static func localRotation(face: PenRingFace, turnDegrees: Double) -> Double {
        guard face == .destination else { return turnDegrees }
        return turnDegrees - (turnDegrees < 0 ? -180 : 180)
    }

    static func cylinderProjection(face: PenRingFace, turnDegrees: Double, reduceMotion: Bool) -> CylinderProjection {
        guard !reduceMotion else { return CylinderProjection(xOffset: 0, widthScale: 1, sideLight: 1, opacity: 1) }
        let localDegrees = localRotation(face: face, turnDegrees: turnDegrees)
        let radians = localDegrees * .pi / 180
        return CylinderProjection(
            xOffset: CGFloat(sin(radians) * 92),
            widthScale: CGFloat(max(0.08, abs(cos(radians)))),
            sideLight: 1,
            opacity: 1
        )
    }

    private static func committedFace(for phase: RitualPhase) -> PenRingFace {
        switch phase {
        case .locked, .unlocking: .source
        case .ready, .holdPending, .holding, .paused, .relocking, .saving, .saveFailed, .completed: .destination
        }
    }
}
