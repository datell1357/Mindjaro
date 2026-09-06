import SwiftUI

public enum DesignTokens {
    public enum TextStyle: Sendable {
        case screenTitle
        case sectionTitle
        case body
        case secondary
        case caption
    }

    public static let spacingUnit: CGFloat = 4
    public static let spacing1: CGFloat = 4
    public static let spacing2: CGFloat = 8
    public static let spacing3: CGFloat = 12
    public static let spacing4: CGFloat = 16
    public static let spacing5: CGFloat = 20
    public static let spacing6: CGFloat = 24
    public static let spacing8: CGFloat = 32

    public static let smallCornerRadius: CGFloat = 12
    public static let cardCornerRadius: CGFloat = 20
    public static let largeCornerRadius: CGFloat = 28

    public static let minimumTouchTarget: CGFloat = 44
    public static let focusRingWidth: CGFloat = 3

    public static let feedbackDuration: TimeInterval = 0.12
    public static let settleDuration: TimeInterval = 0.26
    public static let holdDelay: TimeInterval = 0.12

    public static let normalTextContrastMinimum: Double = 4.5
    public static let largeTextContrastMinimum: Double = 3.0

    public static func font(for style: TextStyle) -> Font {
        switch style {
        case .screenTitle:
            .system(.title, design: .default).weight(.bold)
        case .sectionTitle:
            .system(.title3, design: .default).weight(.bold)
        case .body:
            .system(.body, design: .default).weight(.medium)
        case .secondary:
            .system(.subheadline, design: .default).weight(.medium)
        case .caption:
            .system(.caption, design: .default).weight(.bold)
        }
    }
}
