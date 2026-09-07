import SwiftUI
import MaeumjaroDomain

/// The full texture stays stationary; only its visible top edge drains.
/// Surface movement is driven by progress, so pausing also freezes the meniscus.
struct LiquidMask: View {
    let progress: Double
    let initialFill: Double
    let intensity: Intensity
    var reduceMotion = false

    init(progress: Double, initialFill: Double, intensity: Intensity = .default, reduceMotion: Bool = false) {
        self.progress = progress
        self.initialFill = initialFill
        self.intensity = intensity
        self.reduceMotion = reduceMotion
    }

    var body: some View {
        GeometryReader { proxy in
            let surface = LiquidSurfaceGeometry(
                height: proxy.size.height, initialFill: initialFill,
                progress: progress, reduceMotion: reduceMotion
            )
            Image("PenLiquidFull")
                .resizable()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .saturation(0)
                .brightness(0.32)
                .colorMultiply(intensity.liquidColor)
                .mask {
                    LiquidSurfaceMask(top: surface.top, curvature: surface.curvature)
                        .animation(reduceMotion ? nil : .linear(duration: 1.0 / 60.0), value: progress)
                }
                .accessibilityHidden(true)
        }
        .clipped()
    }
}

struct LiquidSurfaceGeometry {
    let top: Double
    let curvature: Double

    init(height: Double, initialFill: Double, progress: Double, reduceMotion: Bool) {
        let p = min(max(progress, 0), 1)
        let remaining = height * min(max(initialFill, 0), 1) * (1 - p)
        top = height - remaining
        // Tiny curved surface in source-artboard units. It never extends above
        // the specified liquid level, and disappears at full/empty endpoints.
        let available = min(top, remaining)
        // A smooth envelope avoids a visible snap at either endpoint while
        // keeping the paused frame stable because it is derived only from p.
        let envelope = sin(p * .pi)
        let wave = reduceMotion ? 1 : 1 + 0.12 * sin(p * .pi * 4)
        curvature = max(0, min(height * 6 / 414 * envelope * wave, available))
    }
}

private extension Intensity {
    var liquidColor: Color {
        switch rawValue {
        case 1: .init(red: 0.55, green: 1.00, blue: 0.85) // mint
        case 2: .init(red: 0.40, green: 0.91, blue: 1.00) // aqua
        case 3: .init(red: 0.52, green: 0.78, blue: 1.00) // sky
        case 4: .init(red: 0.78, green: 0.67, blue: 1.00) // lilac
        case 5: .init(red: 1.00, green: 0.69, blue: 0.77) // peach pink
        default: .accentColor
        }
    }
}

private struct LiquidSurfaceMask: Shape {
    var top: Double
    var curvature: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(top, curvature) }
        set {
            top = newValue.first
            curvature = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        guard top < rect.height else { return Path() }
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: top))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: top),
                          control: CGPoint(x: rect.midX, y: top + curvature * 2))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
