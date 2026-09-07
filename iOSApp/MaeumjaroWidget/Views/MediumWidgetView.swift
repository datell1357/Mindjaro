import SwiftUI
import MaeumjaroDomain

struct MediumWidgetView: View {
    let entry: MaeumjaroTimelineEntry
    let palette: ThemePalette

    var body: some View {
        SmallWidgetView(entry: entry, palette: palette)
            .accessibilityLabel(WidgetAccessibilityContent.medium(strength: entry.strength, summary: entry.today).label)
            .accessibilityValue(WidgetAccessibilityContent.medium(strength: entry.strength, summary: entry.today).value)
            .accessibilityHint(WidgetAccessibilityContent.medium(strength: entry.strength, summary: entry.today).hint)
    }
}
