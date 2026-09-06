import MaeumjaroDomain
import SwiftUI

public struct IntensityControlStyle: ButtonStyle {
    public let palette: ThemePalette
    public let isSelected: Bool

    public init(
        palette: ThemePalette = .quietIvory,
        isSelected: Bool = false
    ) {
        self.palette = palette
        self.isSelected = isSelected
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignTokens.font(for: .body))
            .foregroundStyle((isSelected ? palette.accentForeground : palette.ink).color)
            .frame(minWidth: DesignTokens.minimumTouchTarget, minHeight: DesignTokens.minimumTouchTarget)
            .padding(.horizontal, DesignTokens.spacing2)
            .background((isSelected ? palette.accent : palette.surface).color)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.smallCornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.smallCornerRadius)
                    .stroke(palette.border.color, lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: DesignTokens.feedbackDuration), value: configuration.isPressed)
    }

    public static func profile(for intensity: Intensity) -> IntensityProfile {
        IntensityProfile(intensity: intensity)
    }
}
