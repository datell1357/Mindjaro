import Foundation
import MaeumjaroDomain
import SwiftUI

public struct ThemeColor: Hashable, Sendable {
    public let hex: String

    public init(hex: String) {
        let value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        self.hex = value.hasPrefix("#") ? value.uppercased() : "#\(value.uppercased())"
    }

    public var color: Color {
        let value = String(hex.dropFirst())
        let red = Double(Int(value.prefix(2), radix: 16) ?? 0) / 255
        let green = Double(Int(value.dropFirst(2).prefix(2), radix: 16) ?? 0) / 255
        let blue = Double(Int(value.dropFirst(4).prefix(2), radix: 16) ?? 0) / 255
        return Color(red: red, green: green, blue: blue)
    }
}

public enum ThemeVariant: String, CaseIterable, Hashable, Sendable {
    case light
    case dark
    case highContrastLight
    case highContrastDark
}

public enum TextContrastSize: Sendable {
    case normal
    case large
}

public struct ThemePalette: Hashable, Sendable {
    public let themeID: ThemeID
    public let variant: ThemeVariant
    public let background: ThemeColor
    public let surface: ThemeColor
    public let ink: ThemeColor
    public let accent: ThemeColor
    public let highlight: ThemeColor
    public let secondaryInk: ThemeColor
    public let border: ThemeColor
    public let accentForeground: ThemeColor

    public var textPrimary: ThemeColor { ink }
    public var textSecondary: ThemeColor { secondaryInk }

    public static let quietIvory = palette(for: .quietIvory)
    public static let midnightInk = palette(for: .midnightInk)
    public static let forestMist = palette(for: .forestMist)

    public static func palette(
        for themeID: ThemeID,
        variant: ThemeVariant = .light
    ) -> ThemePalette {
        switch variant {
        case .light:
            switch themeID {
            case .quietIvory:
                return make(
                    themeID: themeID,
                    variant: variant,
                    background: "#F5F1E8",
                    surface: "#FFFCF7",
                    ink: "#1F2328",
                    accent: "#4F7D75",
                    highlight: "#E9856B",
                    secondaryInk: "#5B625F",
                    border: "#D9D7D0",
                    accentForeground: "#FFFFFF"
                )
            case .midnightInk:
                return make(
                    themeID: themeID,
                    variant: variant,
                    background: "#0E1418",
                    surface: "#182127",
                    ink: "#F2F4EF",
                    accent: "#73B7A9",
                    highlight: "#F09A7C",
                    secondaryInk: "#C5D0CC",
                    border: "#35434A",
                    accentForeground: "#11181C"
                )
            case .forestMist:
                return make(
                    themeID: themeID,
                    variant: variant,
                    background: "#EEF3ED",
                    surface: "#FAFCF8",
                    ink: "#1D2B24",
                    accent: "#3E7460",
                    highlight: "#C77C67",
                    secondaryInk: "#53665A",
                    border: "#D4DED5",
                    accentForeground: "#FFFFFF"
                )
            }
        case .dark:
            switch themeID {
            case .quietIvory:
                return make(
                    themeID: themeID,
                    variant: variant,
                    background: "#1B1814",
                    surface: "#2A241D",
                    ink: "#FFF9EF",
                    accent: "#9DD6C7",
                    highlight: "#FFB39E",
                    secondaryInk: "#D7CEC0",
                    border: "#4A4035",
                    accentForeground: "#111412"
                )
            case .midnightInk:
                return make(
                    themeID: themeID,
                    variant: variant,
                    background: "#070A0C",
                    surface: "#10181D",
                    ink: "#F2F4EF",
                    accent: "#9FE3D1",
                    highlight: "#FFBA9F",
                    secondaryInk: "#CBD8D3",
                    border: "#33434A",
                    accentForeground: "#07100D"
                )
            case .forestMist:
                return make(
                    themeID: themeID,
                    variant: variant,
                    background: "#111A15",
                    surface: "#1A2920",
                    ink: "#F2F7F0",
                    accent: "#8FC9AB",
                    highlight: "#F1A292",
                    secondaryInk: "#C7D8CC",
                    border: "#344A3B",
                    accentForeground: "#09110C"
                )
            }
        case .highContrastLight:
            switch themeID {
            case .quietIvory:
                return highContrastLight(themeID: themeID, accent: "#245C54", highlight: "#9B321B")
            case .midnightInk:
                return highContrastLight(themeID: themeID, accent: "#005A4C", highlight: "#8A260F")
            case .forestMist:
                return highContrastLight(themeID: themeID, accent: "#245C54", highlight: "#8A2F1D")
            }
        case .highContrastDark:
            switch themeID {
            case .quietIvory, .midnightInk, .forestMist:
                return make(
                    themeID: themeID,
                    variant: variant,
                    background: "#000000",
                    surface: "#101010",
                    ink: "#FFFFFF",
                    accent: "#B5F4E5",
                    highlight: "#FFD1C2",
                    secondaryInk: "#FFFFFF",
                    border: "#FFFFFF",
                    accentForeground: "#000000"
                )
            }
        }
    }

    /// Resolves the named palette against the system appearance and contrast setting.
    /// A named theme remains independent from the system color scheme (for example,
    /// midnightInk does not force the app into system dark mode).
    public static func palette(
        for themeID: ThemeID,
        colorScheme: ColorScheme,
        contrast: ColorSchemeContrast
    ) -> ThemePalette {
        let variant: ThemeVariant
        switch (colorScheme, contrast) {
        case (.light, .increased): variant = .highContrastLight
        case (.dark, .increased): variant = .highContrastDark
        case (.dark, _): variant = .dark
        case (.light, _): variant = .light
        @unknown default: variant = .light
        }
        return palette(for: themeID, variant: variant)
    }

    public static func allPalettes(for themeID: ThemeID) -> [ThemePalette] { ThemeVariant.allCases.map { palette(for: themeID, variant: $0) } }

    public func contrastRatio(foreground: ThemeColor, background: ThemeColor) -> Double { Self.contrastRatio(foreground: foreground, background: background) }

    public static func contrastRatio(foreground: ThemeColor, background: ThemeColor) -> Double {
        let foregroundLuminance = relativeLuminance(of: foreground)
        let backgroundLuminance = relativeLuminance(of: background)
        let lighter = max(foregroundLuminance, backgroundLuminance)
        let darker = min(foregroundLuminance, backgroundLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    public func meetsContrast(
        foreground: ThemeColor,
        background: ThemeColor,
        size: TextContrastSize
    ) -> Bool {
        let requiredRatio: Double = switch size {
        case .normal:
            DesignTokens.normalTextContrastMinimum
        case .large:
            DesignTokens.largeTextContrastMinimum
        }
        return contrastRatio(foreground: foreground, background: background) >= requiredRatio
    }

    public var passesAccessibilityContrast: Bool {
        meetsContrast(foreground: ink, background: background, size: .normal)
            && meetsContrast(foreground: ink, background: surface, size: .normal)
            && meetsContrast(foreground: secondaryInk, background: background, size: .normal)
            && meetsContrast(foreground: secondaryInk, background: surface, size: .normal)
            && meetsContrast(foreground: accent, background: surface, size: .normal)
            && meetsContrast(foreground: accentForeground, background: accent, size: .normal)
    }

    private static func make(
        themeID: ThemeID,
        variant: ThemeVariant,
        background: String,
        surface: String,
        ink: String,
        accent: String,
        highlight: String,
        secondaryInk: String,
        border: String,
        accentForeground: String
    ) -> ThemePalette {
        ThemePalette(
            themeID: themeID,
            variant: variant,
            background: ThemeColor(hex: background),
            surface: ThemeColor(hex: surface),
            ink: ThemeColor(hex: ink),
            accent: ThemeColor(hex: accent),
            highlight: ThemeColor(hex: highlight),
            secondaryInk: ThemeColor(hex: secondaryInk),
            border: ThemeColor(hex: border),
            accentForeground: ThemeColor(hex: accentForeground)
        )
    }

    private static func highContrastLight(
        themeID: ThemeID,
        accent: String,
        highlight: String
    ) -> ThemePalette {
        make(
            themeID: themeID,
            variant: .highContrastLight,
            background: "#FFFFFF",
            surface: "#FFFFFF",
            ink: "#000000",
            accent: accent,
            highlight: highlight,
            secondaryInk: "#202020",
            border: "#000000",
            accentForeground: "#FFFFFF"
        )
    }

    private static func relativeLuminance(of color: ThemeColor) -> Double {
        let value = String(color.hex.dropFirst())
        let channels = [
            Double(Int(value.prefix(2), radix: 16) ?? 0) / 255,
            Double(Int(value.dropFirst(2).prefix(2), radix: 16) ?? 0) / 255,
            Double(Int(value.dropFirst(4).prefix(2), radix: 16) ?? 0) / 255
        ].map { channel in
            channel <= 0.03928
                ? channel / 12.92
                : pow((channel + 0.055) / 1.055, 2.4)
        }
        return (0.2126 * channels[0]) + (0.7152 * channels[1]) + (0.0722 * channels[2])
    }
}
