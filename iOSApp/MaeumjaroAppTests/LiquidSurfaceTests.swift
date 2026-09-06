import XCTest
import SwiftUI
@testable import Maeumjaro

final class LiquidSurfaceTests: XCTestCase {
    @MainActor
    func testRendererCapturesNormalAndReducedSurfaceAtIntermediateProgress() throws {
        for reduced in [false, true] {
            for progress in [0.3125, 0.4375, 1.0] {
                let renderer = ImageRenderer(content:
                    LiquidMask(progress: progress, initialFill: 1, reduceMotion: reduced)
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
        XCTAssertEqual(first.curvature, second.curvature)
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
