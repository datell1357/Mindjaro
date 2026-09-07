import XCTest
import SwiftUI
import MaeumjaroDomain
@testable import Maeumjaro

final class LiquidSurfaceTests: XCTestCase {
    @MainActor
    func testAllIntensitiesRenderDistinctColorsAtTheSameFill() throws {
        var rendered: [Data] = []
        for intensity in Intensity.allCases {
            let profile = IntensityProfile(intensity: intensity)
            XCTAssertEqual(profile.initialFill, 1)
            let renderer = ImageRenderer(content:
                LiquidMask(progress: 0, initialFill: profile.initialFill, intensity: intensity)
                    .frame(width: 126, height: 414).background(.white)
            )
            let image = try XCTUnwrap(renderer.uiImage)
            rendered.append(try XCTUnwrap(image.pngData()))
            let attachment = XCTAttachment(image: image)
            attachment.name = "liquid-intensity-\(intensity.rawValue)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        XCTAssertEqual(Set(rendered).count, 5)
        let palette = ImageRenderer(content: HStack(spacing: 20) {
            ForEach(Intensity.allCases, id: \.rawValue) { intensity in
                LiquidMask(progress: 0, initialFill: 1, intensity: intensity)
                    .frame(width: 63, height: 207)
            }
        }.padding(24).background(Color(red: 0.984, green: 0.969, blue: 0.941)))
        let comparison = XCTAttachment(image: try XCTUnwrap(palette.uiImage))
        comparison.name = "clear-liquid-five-colors"
        comparison.lifetime = .keepAlways
        add(comparison)
    }
    @MainActor
    func testRendererCapturesNormalAndReducedSurfaceAtIntermediateProgress() throws {
        for reduced in [false, true] {
            for progress in [0.3125, 0.4375, 1.0] {
                let renderer = ImageRenderer(content:
                    LiquidMask(progress: progress, initialFill: 1, intensity: .three, reduceMotion: reduced)
                        .frame(width: 126, height: 414).background(.black)
                )
                renderer.scale = 2
                let image = try XCTUnwrap(renderer.uiImage)
                let attachment = XCTAttachment(image: image)
                attachment.name = "liquid-reduced-\(reduced)-progress-\(progress)"
                attachment.lifetime = .keepAlways
                add(attachment)
                XCTAssertEqual(image.size.width, 126)
                XCTAssertEqual(image.size.height, 414)
            }
        }
    }
    func testSurfaceKeepsContractLevelsInBothMotionModes() {
        for reduced in [false, true] {
            for fill in [0.2, 0.4, 0.6, 0.8, 1.0] {
                for progress in [0.0, 0.25, 0.5, 0.75, 1.0] {
                    let value = LiquidSurfaceGeometry(height: 414, initialFill: fill, progress: progress, reduceMotion: reduced)
                    XCTAssertEqual(value.top, 414 * (1 - fill * (1 - progress)), accuracy: 1e-9)
                    XCTAssertGreaterThanOrEqual(value.curvature, 0)
                    XCTAssertLessThanOrEqual(value.curvature, 414 - value.top + 1e-9)
                }
            }
        }
    }

    func testReducedMotionStopsSurfaceOscillationButNotDrain() {
        let first = LiquidSurfaceGeometry(height: 414, initialFill: 1, progress: 0.3125, reduceMotion: true)
        let second = LiquidSurfaceGeometry(height: 414, initialFill: 1, progress: 0.4375, reduceMotion: true)
        XCTAssertNotEqual(first.curvature, second.curvature)
        XCTAssertEqual(first.curvature, 6 * sin(0.3125 * .pi), accuracy: 1e-9)
        XCTAssertEqual(second.curvature, 6 * sin(0.4375 * .pi), accuracy: 1e-9)
        XCTAssertGreaterThan(second.top, first.top)
        let normalFirst = LiquidSurfaceGeometry(height: 414, initialFill: 1, progress: 0.3125, reduceMotion: false)
        let normalSecond = LiquidSurfaceGeometry(height: 414, initialFill: 1, progress: 0.4375, reduceMotion: false)
        XCTAssertNotEqual(normalFirst.curvature, normalSecond.curvature)
        XCTAssertEqual(normalFirst.top, first.top)
        XCTAssertEqual(normalSecond.top, second.top)
    }

    func testFullAndEmptyHaveNoSurfaceBulge() {
        for reduced in [false, true] {
            XCTAssertEqual(LiquidSurfaceGeometry(height: 414, initialFill: 1, progress: 0, reduceMotion: reduced).curvature, 0)
            XCTAssertEqual(LiquidSurfaceGeometry(height: 414, initialFill: 1, progress: 1, reduceMotion: reduced).curvature, 0)
        }
    }
}
