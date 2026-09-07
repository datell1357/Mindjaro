import Foundation
import MaeumjaroDomain
import XCTest
import SwiftUI
@testable import Maeumjaro

final class InjectionRingPresentationTests: XCTestCase {
    @MainActor
    func testOriginalRingEndpointsAndIntermediateRender() throws {
        for (angle, asset) in [(0.0, "PenRingLocked"), (180.0, "PenRingReady")] {
            let rendered = ImageRenderer(content: RingVisual(turnDegrees: angle, phase: .unlocking, scale: 1, reduceMotion: false))
            let original = ImageRenderer(content: Image(asset).resizable().frame(width: 300, height: 112))
            XCTAssertEqual(try XCTUnwrap(rendered.uiImage?.pngData()), try XCTUnwrap(original.uiImage?.pngData()))
        }
        let renderer = ImageRenderer(content: VStack(spacing: 16) {
            ForEach([0.0, 45, 90, 135, 180], id: \.self) { angle in
                RingVisual(turnDegrees: angle, phase: .unlocking, scale: 1, reduceMotion: false)
            }
        }.padding(20).background(Color(red: 0.984, green: 0.969, blue: 0.941)))
        let attachment = XCTAttachment(image: try XCTUnwrap(renderer.uiImage))
        attachment.name = "original-ring-turns"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
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

    func testCylinderProjectionKeepsBodyOpaqueAndHidesBackfaceDetails() {
        let front = InjectionRingPresentation.cylinderProjection(face: .destination, turnDegrees: 180, reduceMotion: false)
        let edge = InjectionRingPresentation.cylinderProjection(face: .source, turnDegrees: 90, reduceMotion: false)

        XCTAssertEqual(front.widthScale, 1, accuracy: 0.0001)
        XCTAssertLessThan(edge.widthScale, 0.2)
        XCTAssertEqual(front.opacity, 1, accuracy: 0.0001)
        XCTAssertEqual(edge.opacity, 1, accuracy: 0.0001)
        XCTAssertEqual(edge.widthScale, 0.08, accuracy: 0.0001)
        XCTAssertEqual(edge.xOffset, 92, accuracy: 0.0001)
    }

    func testReducedMotionProjectionDoesNotCompressRing() {
        let projection = InjectionRingPresentation.cylinderProjection(face: .source, turnDegrees: 90, reduceMotion: true)
        XCTAssertEqual(projection.widthScale, 1, accuracy: 0.0001)
        XCTAssertEqual(projection.opacity, 1, accuracy: 0.0001)
    }

    func testCanonicalFacesHaveUnprojectedEndpoints() {
        let source = InjectionRingPresentation.cylinderProjection(face: .source, turnDegrees: 0, reduceMotion: false)
        let destination = InjectionRingPresentation.cylinderProjection(face: .destination, turnDegrees: 180, reduceMotion: false)

        XCTAssertEqual(source.widthScale, 1, accuracy: 0.0001)
        XCTAssertEqual(source.xOffset, 0, accuracy: 0.0001)
        XCTAssertEqual(destination.widthScale, 1, accuracy: 0.0001)
        XCTAssertEqual(destination.xOffset, 0, accuracy: 0.0001)
    }
}
