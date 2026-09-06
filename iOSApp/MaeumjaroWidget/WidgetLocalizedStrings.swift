import Foundation

private final class WidgetLocalizedStringsBundleAnchor: NSObject {}

enum WidgetLocalizedStrings {
    static let bundle = Bundle(for: WidgetLocalizedStringsBundleAnchor.self)
    static let brand = String(localized: "widget.brand", bundle: bundle)
    static let description = String(localized: "widget.configuration.description", bundle: bundle)
    static let start = String(localized: "widget.start", bundle: bundle)

    static func todaySummary(count: Int, sum: Int) -> String {
        String(format: String(localized: "widget.today.summary.format", bundle: bundle), locale: Locale.current, Int64(count), String(sum))
    }

    static func strength(_ value: Int) -> String {
        String(format: String(localized: "widget.strength.format", bundle: bundle), locale: Locale.current, Int64(value))
    }

    static func smallAccessibilityValue(strength: Int, count: Int) -> String {
        String(format: String(localized: "widget.accessibility.small.value.format", bundle: bundle), locale: Locale.current, Int64(strength), Int64(count))
    }

    static func mediumAccessibilityValue(strength: Int, count: Int) -> String {
        String(format: String(localized: "widget.accessibility.medium.value.format", bundle: bundle), locale: Locale.current, Int64(strength), Int64(count))
    }

    static let smallAccessibilityLabel = String(localized: "widget.accessibility.small.label", bundle: bundle)
    static let smallAccessibilityHint = String(localized: "widget.accessibility.small.hint", bundle: bundle)
    static let mediumAccessibilityLabel = String(localized: "widget.accessibility.medium.label", bundle: bundle)
    static let mediumAccessibilityHint = String(localized: "widget.accessibility.medium.hint", bundle: bundle)
}
