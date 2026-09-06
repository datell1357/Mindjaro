import MaeumjaroDomain
import MaeumjaroIntents
import SwiftUI

struct WidgetIntensityControl: View {
    let strength: Intensity
    let palette: ThemePalette
    var body: some View {
        HStack(spacing: 4) {
            Button(intent: SetStrengthIntent(delta: -1)) { Image(systemName: "minus").frame(width: DesignTokens.minimumTouchTarget, height: DesignTokens.minimumTouchTarget) }
                .disabled(strength == .one)
            Text(WidgetLocalizedStrings.strength(strength.rawValue)).font(DesignTokens.font(for: .secondary)).lineLimit(1).minimumScaleFactor(0.8)
            Button(intent: SetStrengthIntent(delta: 1)) { Image(systemName: "plus").frame(width: DesignTokens.minimumTouchTarget, height: DesignTokens.minimumTouchTarget) }
                .disabled(strength == .five)
        }
        .buttonStyle(.plain)
        .foregroundStyle(palette.accentForeground.color)
        .background(palette.accent.color, in: RoundedRectangle(cornerRadius: DesignTokens.smallCornerRadius))
    }
}
