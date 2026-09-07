import SwiftUI
import MaeumjaroShared
import WidgetKit

struct MaeumjaroWidget: Widget {
    let kind = AppIdentifiers.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MaeumjaroTimelineProvider()) { entry in
            MaeumjaroWidgetEntryView(entry: entry)
        }
        .configurationDisplayName(WidgetLocalizedStrings.brand)
        .description(WidgetLocalizedStrings.description)
        .supportedFamilies([.systemSmall, .accessoryCircular, .systemMedium])
    }
}

struct MaeumjaroWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    let entry: MaeumjaroTimelineEntry

    var body: some View {
        let palette = ThemePalette.palette(
            for: entry.theme,
            colorScheme: colorScheme,
            contrast: colorSchemeContrast
        )

        Group {
            if family == .accessoryCircular { CircularWidgetView(entry: entry) }
            else if family == .systemMedium { MediumWidgetView(entry: entry, palette: palette) }
            else { SmallWidgetView(entry: entry, palette: palette) }
        }
        .redacted(reason: entry.isPlaceholder ? .placeholder : [])
        .containerBackground(for: .widget) { palette.background.color }
    }
}
