import MaeumjaroDomain
import SwiftUI

public struct HeatmapColorScale: Sendable {
    public let palette: ThemePalette

    public init(palette: ThemePalette = .quietIvory) {
        self.palette = palette
    }

    public func color(for intensity: Intensity) -> Color {
        let fraction = Double(intensity.rawValue - Intensity.minimumRawValue)
            / Double(Intensity.maximumRawValue - Intensity.minimumRawValue)
        let opacity = 0.35 + (fraction * 0.65)
        return palette.accent.color.opacity(opacity)
    }

    public func color(forCount count: Int) -> Color {
        guard count > 0 else { return palette.background.color }
        let level = min(count, Intensity.maximumRawValue)
        guard let intensity = Intensity(rawValue: level) else {
            return palette.background.color
        }
        return color(for: intensity)
    }
}
