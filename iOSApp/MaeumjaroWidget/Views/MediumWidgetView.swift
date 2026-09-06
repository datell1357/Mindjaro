import SwiftUI
import MaeumjaroDomain
import MaeumjaroIntents

struct MediumWidgetView: View {
    let entry: MaeumjaroTimelineEntry
    let palette: ThemePalette

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacing2) {
            HStack { VStack(alignment: .leading, spacing: 2) { Text(WidgetLocalizedStrings.brand).font(DesignTokens.font(for: .caption)).foregroundStyle(palette.secondaryInk.color); Text(WidgetLocalizedStrings.todaySummary(count: entry.today.count, sum: entry.today.sum)).font(DesignTokens.font(for: .secondary)) }; Spacer(); Link(destination: URL(string: "maeumjaro://inject?source=widget")!) { Label(WidgetLocalizedStrings.start, systemImage: "play.fill") }.buttonStyle(.borderedProminent).tint(palette.accent.color).foregroundStyle(palette.accentForeground.color).frame(minWidth: 64, minHeight: DesignTokens.minimumTouchTarget) }
            HStack(spacing: 4) { ForEach(Intensity.allCases, id: \.rawValue) { intensity in Button(intent: SetStrengthIntent(target: intensity.rawValue)) { Text("\(intensity.rawValue)").frame(maxWidth: .infinity, minHeight: DesignTokens.minimumTouchTarget) }.buttonStyle(.borderedProminent).tint(intensity == entry.strength ? palette.accent.color : palette.surface.color).foregroundStyle(intensity == entry.strength ? palette.accentForeground.color : palette.ink.color) } }
        }.padding(DesignTokens.spacing4).foregroundStyle(palette.ink.color)
            .accessibilityLabel(WidgetAccessibilityContent.medium(strength: entry.strength, summary: entry.today).label)
            .accessibilityValue(WidgetAccessibilityContent.medium(strength: entry.strength, summary: entry.today).value)
            .accessibilityHint(WidgetAccessibilityContent.medium(strength: entry.strength, summary: entry.today).hint)
    }
}
