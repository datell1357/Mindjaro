import MaeumjaroDomain
import MaeumjaroShared

struct WidgetAccessibilityContent: Equatable, Codable {
    let label: String
    let value: String
    let hint: String
    static func small(strength: Intensity, summary: TodaySummarySnapshot) -> Self { Self(label: WidgetLocalizedStrings.smallAccessibilityLabel, value: WidgetLocalizedStrings.smallAccessibilityValue(strength: strength.rawValue, count: summary.count), hint: WidgetLocalizedStrings.smallAccessibilityHint) }
    static func medium(strength: Intensity, summary: TodaySummarySnapshot) -> Self { Self(label: WidgetLocalizedStrings.mediumAccessibilityLabel, value: WidgetLocalizedStrings.mediumAccessibilityValue(strength: strength.rawValue, count: summary.count), hint: WidgetLocalizedStrings.mediumAccessibilityHint) }
}
