import SwiftUI
import XCTest
import MaeumjaroDomain
@testable import Maeumjaro

final class ThemeAppearanceTests: XCTestCase {
    func testResolverCoversAllThemeIDsAndAppearanceVariants() {
        for themeID in ThemeID.allCases {
            XCTAssertEqual(ThemePalette.palette(for: themeID, colorScheme: .light, contrast: .standard).variant, .light)
            XCTAssertEqual(ThemePalette.palette(for: themeID, colorScheme: .dark, contrast: .standard).variant, .dark)
            XCTAssertEqual(ThemePalette.palette(for: themeID, colorScheme: .light, contrast: .increased).variant, .highContrastLight)
            XCTAssertEqual(ThemePalette.palette(for: themeID, colorScheme: .dark, contrast: .increased).variant, .highContrastDark)
        }
    }

    func testAppearanceResolutionPreservesNamedThemeAndReadableContent() {
        for themeID in ThemeID.allCases {
            for scheme in [ColorScheme.light, .dark] {
                for contrast in [ColorSchemeContrast.standard, .increased] {
                    let palette = ThemePalette.palette(for: themeID, colorScheme: scheme, contrast: contrast)
                    XCTAssertEqual(palette.themeID, themeID)
                    XCTAssertTrue(palette.passesAccessibilityContrast, "\(themeID) / \(palette.variant)")
                    XCTAssertTrue(palette.meetsContrast(foreground: palette.secondaryInk, background: palette.background, size: .normal))
                }
            }
        }
    }
}
