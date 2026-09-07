import SwiftUI
import UIKit
import XCTest
import WidgetKit
import MaeumjaroDomain
import MaeumjaroShared

@MainActor
final class WidgetAppearanceRenderTests: XCTestCase {
    func testPenAssetExistsInWidgetRenderBundle() throws {
        XCTAssertNotNil(UIImage(named: "PenLocked", in: WidgetLocalizedStrings.bundle, compatibleWith: nil))
    }
    func testWidgetAppearanceRendersExactMatrix() throws {
        let summaries: [(name: String, snapshot: TodaySummarySnapshot)] = [
            ("zero", summary(completionCount: 0, intensitySum: 0)),
            ("nonzero", summary(completionCount: 2, intensitySum: 7))
        ]
        let strengths: [(name: String, value: Intensity)] = [
            ("strength1", .one),
            ("strength5", .five)
        ]
        let appearances: [(name: String, scheme: ColorScheme)] = [
            ("light", .light),
            ("dark", .dark)
        ]
        let themes: [(name: String, value: ThemeID)] = [
            ("quietIvory", .quietIvory),
            ("midnightInk", .midnightInk),
            ("forestMist", .forestMist)
        ]
        let families: [(name: String, value: WidgetFamily, size: CGSize)] = [
            ("small", .systemSmall, CGSize(width: 158, height: 158)),
            ("medium", .systemMedium, CGSize(width: 338, height: 158)),
            ("circular", .accessoryCircular, CGSize(width: 64, height: 64))
        ]

        for family in families {
            for appearance in appearances {
                for theme in themes {
                    for strength in strengths {
                        for summary in summaries {
                            let entry = MaeumjaroTimelineEntry(
                                date: Date(timeIntervalSince1970: 1_725_278_400),
                                strength: strength.value,
                                today: summary.snapshot,
                                theme: theme.value,
                                isPlaceholder: false
                            )
                            let palette = ThemePalette.palette(
                                for: entry.theme,
                                colorScheme: appearance.scheme,
                                contrast: .standard
                            )
                            let image = try render(
                                family: family.value,
                                size: family.size,
                                entry: entry,
                                palette: palette,
                                colorScheme: appearance.scheme
                            )

                            let filename = "widget_\(family.name)_\(appearance.name)_\(theme.name)_\(strength.name)_\(summary.name).png"
                            let attachment = XCTAttachment(image: image)
                            attachment.name = filename
                            attachment.lifetime = .keepAlways
                            add(attachment)

                            let pixelWidth = try XCTUnwrap(image.cgImage?.width, "Missing rendered image pixels for \(filename)")
                            let pixelHeight = try XCTUnwrap(image.cgImage?.height, "Missing rendered image pixels for \(filename)")
                            XCTAssertEqual(pixelWidth, Int(family.size.width), filename)
                            XCTAssertEqual(pixelHeight, Int(family.size.height), filename)
                        }
                    }
                }
            }
        }
    }

    func testWidgetPaletteForegroundsMeetContrastForRenderedControls() {
        for theme in ThemeID.allCases {
            for variant in [ThemeVariant.light, .dark] {
                let palette = ThemePalette.palette(for: theme, variant: variant)
                let context = "\(theme.rawValue) / \(variant.rawValue)"

                XCTAssertTrue(
                    palette.meetsContrast(foreground: palette.secondaryInk, background: palette.background, size: .normal),
                    "Title secondaryInk/background contrast failed: \(context)"
                )
                XCTAssertTrue(
                    palette.meetsContrast(foreground: palette.ink, background: palette.background, size: .normal),
                    "Body ink/background contrast failed: \(context)"
                )
                XCTAssertTrue(
                    palette.meetsContrast(foreground: palette.accentForeground, background: palette.accent, size: .normal),
                    "Selected control accentForeground/accent contrast failed: \(context)"
                )
                XCTAssertTrue(
                    palette.meetsContrast(foreground: palette.ink, background: palette.surface, size: .normal),
                    "Unselected control ink/surface contrast failed: \(context)"
                )
            }
        }
    }

    private func summary(completionCount: Int, intensitySum: Int) -> TodaySummarySnapshot {
        TodaySummarySnapshot(
            localDate: "2026-09-06",
            completionCount: completionCount,
            intensitySum: intensitySum,
            writer: .app,
            updatedAt: Date(timeIntervalSince1970: 1_725_278_400),
            revision: 1
        )
    }

    private func render(
        family: WidgetFamily,
        size: CGSize,
        entry: MaeumjaroTimelineEntry,
        palette: ThemePalette,
        colorScheme: ColorScheme
    ) throws -> UIImage {
        let component: AnyView = switch family {
        case .accessoryCircular:
            AnyView(CircularWidgetView(entry: entry))
        case .systemMedium:
            AnyView(MediumWidgetView(entry: entry, palette: palette))
        default:
            AnyView(SmallWidgetView(entry: entry, palette: palette))
        }
        let renderer = ImageRenderer(
            content: ZStack {
                palette.background.color
                component
            }
            .frame(width: size.width, height: size.height)
            .environment(\.colorScheme, colorScheme)
        )
        renderer.scale = 1
        return try XCTUnwrap(renderer.uiImage, "ImageRenderer returned nil for \(family)")
    }
}
