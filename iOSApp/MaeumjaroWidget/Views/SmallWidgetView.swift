import SwiftUI
import MaeumjaroDomain
import WidgetKit

struct SmallWidgetView: View {
    let entry: MaeumjaroTimelineEntry
    let palette: ThemePalette

    private var injectionURL: URL { URL(string: "maeumjaro://inject?source=widget")! }
    private var strengthColor: Color {
        switch entry.strength.rawValue {
        case 1: Color(red: 0.55, green: 1, blue: 0.85)
        case 2: Color(red: 0.40, green: 0.91, blue: 1)
        case 3: Color(red: 0.52, green: 0.78, blue: 1)
        case 4: Color(red: 0.78, green: 0.67, blue: 1)
        default: Color(red: 1, green: 0.69, blue: 0.77)
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            Image("PenLocked", bundle: WidgetLocalizedStrings.bundle)
                    .resizable()
                    .frame(width: 64, height: 96)
                    .frame(width: 24).clipped()
            Circle().fill(strengthColor)
                .overlay(Circle().stroke(palette.border.color, lineWidth: 1))
                .overlay {
                    if entry.today.count > 0 {
                        Image(systemName: "checkmark").font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color(red: 0.15, green: 0.20, blue: 0.22))
                    }
                }
                .frame(width: 14, height: 14)
        }.frame(maxWidth: .infinity, maxHeight: .infinity).foregroundStyle(palette.ink.color)
            .widgetURL(injectionURL)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(WidgetAccessibilityContent.small(strength: entry.strength, summary: entry.today).label)
            .accessibilityValue(WidgetAccessibilityContent.small(strength: entry.strength, summary: entry.today).value)
            .accessibilityHint(WidgetAccessibilityContent.small(strength: entry.strength, summary: entry.today).hint)
    }
}

struct CircularWidgetView: View {
    let entry: MaeumjaroTimelineEntry

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            Image(systemName: "pencil.tip")
                .font(.system(size: 24, weight: .medium))
                .widgetAccentable()
        }
        .widgetURL(URL(string: "maeumjaro://inject?source=widget"))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(WidgetLocalizedStrings.smallAccessibilityLabel)
        .accessibilityValue(WidgetLocalizedStrings.smallAccessibilityValue(strength: entry.strength.rawValue, count: entry.today.count))
        .accessibilityHint(WidgetLocalizedStrings.smallAccessibilityHint)
    }
}
