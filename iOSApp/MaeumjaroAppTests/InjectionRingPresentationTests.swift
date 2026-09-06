import Foundation
import MaeumjaroDomain
import XCTest
@testable import Maeumjaro

final class InjectionRingPresentationTests: XCTestCase {
    func testBothDirectionsSelectFacesAtInterpolatedTurns() {
        for direction in [-1.0, 1.0] {
            for (turn, expected) in [(0.0, PenRingFace.source), (89, .source), (91, .destination), (180, .destination)] {
                XCTAssertEqual(InjectionRingPresentation.presentation(phase: .unlocking, turnDegrees: turn * direction, reduceMotion: false).face, expected)
            }
            for (turn, expected) in [(180.0, PenRingFace.destination), (269, .destination), (271, .source), (360, .source)] {
                XCTAssertEqual(InjectionRingPresentation.presentation(phase: .relocking, turnDegrees: turn * direction, reduceMotion: false).face, expected)
            }
            XCTAssertEqual(InjectionRingPresentation.localRotation(face: .destination, turnDegrees: 180 * direction), 0)
        }
    }

    func testReducedMotionCommitsActualReleasePhase() {
        XCTAssertEqual(InjectionRingPresentation.presentation(phase: .locked, turnDegrees: 360, reduceMotion: true).face, .source)
        XCTAssertEqual(InjectionRingPresentation.presentation(phase: .ready, turnDegrees: -180, reduceMotion: true).face, .destination)
    }

    func testRelockCommitSettlesThroughTheSignedFullTurn() {
        for turn in [-360.0, 360.0] {
            let value = InjectionRingPresentation.presentation(phase: .relocking, turnDegrees: turn, reduceMotion: false)
            XCTAssertEqual(value.face, .source)
            XCTAssertEqual(value.localRotationDegrees, turn)
        }
    }

    func testRelockCancelSettlesBackToCommittedReadyTurn() {
        for turn in [-180.0, 180.0] {
            let value = InjectionRingPresentation.presentation(phase: .relocking, turnDegrees: turn, reduceMotion: false)
            XCTAssertEqual(value.face, .destination)
            XCTAssertEqual(value.localRotationDegrees, 0)
        }
    }

    func testReducedMotionUsesCommittedFaceAndNoRotation() {
        let result = InjectionRingPresentation.presentation(phase: .ready, turnDegrees: 93, reduceMotion: true)

        XCTAssertEqual(result.face, .destination)
        XCTAssertEqual(result.localRotationDegrees, 0)
    }

    func testRingFacesUseCanonicalSignedTurnWithoutUpsideDownTexture() {
        XCTAssertEqual(InjectionRingPresentation.localRotation(face: .source, turnDegrees: 0), 0)
        XCTAssertEqual(InjectionRingPresentation.localRotation(face: .destination, turnDegrees: 180), 0)
        XCTAssertEqual(InjectionRingPresentation.localRotation(face: .source, turnDegrees: 360), 360)
    }
}
