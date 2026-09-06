import SwiftUI

/// The full texture stays stationary; only its visible top edge drains.
/// Surface movement is driven by progress, so pausing also freezes the meniscus.
struct LiquidMask: View {
    let progress: Double
    let initialFill: Double
    var reduceMotion = false

    var body: some View {
        GeometryReader { proxy in
            let surface = LiquidSurfaceGeometry(
                height: proxy.size.height, initialFill: initialFill,
                progress: progress, reduceMotion: reduceMotion
            )
            Image("PenLiquidFull")
                .resizable()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .mask {
                    LiquidSurfaceMask(top: surface.top, curvature: surface.curvature)
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
        let wave = reduceMotion ? 1 : 1 + 0.25 * sin(p * .pi * 8)
        curvature = max(0, min(height * 6 / 414 * wave, available))
    }
}

private struct LiquidSurfaceMask: Shape {
    let top: Double
    let curvature: Double

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
