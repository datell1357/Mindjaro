import SwiftUI

struct SmallWidgetView: View {
    let entry: MaeumjaroTimelineEntry
    let palette: ThemePalette

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacing2) {
            HStack(spacing: DesignTokens.spacing2) {
                Text(WidgetLocalizedStrings.brand).font(DesignTokens.font(for: .caption)).foregroundStyle(palette.secondaryInk.color)
                Spacer(minLength: 0)
                Text(WidgetLocalizedStrings.todaySummary(count: entry.today.count, sum: entry.today.sum)).font(DesignTokens.font(for: .caption)).lineLimit(1).minimumScaleFactor(0.7)
            }
            WidgetIntensityControl(strength: entry.strength, palette: palette)
            Link(destination: URL(string: "maeumjaro://inject?source=widget")!) { Label(WidgetLocalizedStrings.start, systemImage: "play.fill").frame(maxWidth: .infinity, minHeight: DesignTokens.minimumTouchTarget) }.buttonStyle(.borderedProminent).tint(palette.accent.color).foregroundStyle(palette.accentForeground.color)
        }.foregroundStyle(palette.ink.color)
            .accessibilityLabel(WidgetAccessibilityContent.small(strength: entry.strength, summary: entry.today).label)
            .accessibilityValue(WidgetAccessibilityContent.small(strength: entry.strength, summary: entry.today).value)
            .accessibilityHint(WidgetAccessibilityContent.small(strength: entry.strength, summary: entry.today).hint)
    }
}
