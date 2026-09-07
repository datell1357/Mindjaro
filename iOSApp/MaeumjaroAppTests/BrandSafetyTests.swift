import CryptoKit
import Foundation
import XCTest

@testable import Maeumjaro

final class BrandSafetyTests: XCTestCase {
    func testThemeTokensKeepApprovedValuesAndAccessibleVariants() {
        XCTAssertEqual(ThemePalette.quietIvory.background.hex, "#FBF7F0")
        XCTAssertEqual(ThemePalette.quietIvory.surface.hex, "#FFFCF7")
        XCTAssertEqual(ThemePalette.quietIvory.ink.hex, "#1F2328")
        XCTAssertEqual(ThemePalette.quietIvory.accent.hex, "#4F7D75")
        XCTAssertEqual(ThemePalette.quietIvory.highlight.hex, "#E9856B")

        XCTAssertEqual(ThemePalette.midnightInk.background.hex, "#0E1418")
        XCTAssertEqual(ThemePalette.midnightInk.surface.hex, "#182127")
        XCTAssertEqual(ThemePalette.midnightInk.ink.hex, "#F2F4EF")
        XCTAssertEqual(ThemePalette.midnightInk.accent.hex, "#73B7A9")
        XCTAssertEqual(ThemePalette.midnightInk.highlight.hex, "#F09A7C")

        XCTAssertEqual(ThemePalette.forestMist.background.hex, "#EEF3ED")
        XCTAssertEqual(ThemePalette.forestMist.surface.hex, "#FAFCF8")
        XCTAssertEqual(ThemePalette.forestMist.ink.hex, "#1D2B24")
        XCTAssertEqual(ThemePalette.forestMist.accent.hex, "#3E7460")
        XCTAssertEqual(ThemePalette.forestMist.highlight.hex, "#C77C67")

        for palette in ThemePalette.allPalettes(for: .quietIvory)
            + ThemePalette.allPalettes(for: .midnightInk)
            + ThemePalette.allPalettes(for: .forestMist) {
            XCTAssertTrue(palette.passesAccessibilityContrast, palette.variant.rawValue)
        }
    }

    func testPenContractFreezesSchemaGeometryLayerOrderAndDrawingMath() {
        XCTAssertEqual(PenAssetContract.schemaVersion, 5)
        XCTAssertEqual(PenAssetContract.canvasSize, PenCanvasSize(width: 1024, height: 1536))
        XCTAssertEqual(PenAssetContract.ringFrame, PenFrame(x: 362, y: 136, width: 300, height: 112))
        XCTAssertEqual(
            PenAssetContract.liquidWindowFrame,
            PenFrame(x: 449, y: 650, width: 126, height: 414)
        )
        XCTAssertEqual(
            PenAssetContract.layerOrder,
            [.readyBase, .windowEmpty, .maskedLiquidFull, .ringCylinder]
        )
        XCTAssertEqual(
            PenAssetContract.ringPresentation(progress: 0.25, direction: .right),
            PenRingPresentation(face: .source, rotationDegrees: 45)
        )
        XCTAssertEqual(
            PenAssetContract.ringPresentation(progress: 0.75, direction: .right),
            PenRingPresentation(face: .destination, rotationDegrees: -45)
        )
        XCTAssertEqual(PenAssetContract.liquidTopOffset(initialFill: 0.6, progress: 0), 165.6, accuracy: 1e-9)
        XCTAssertEqual(PenAssetContract.liquidTopOffset(initialFill: 0.6, progress: 0.5), 289.8, accuracy: 1e-9)
        XCTAssertEqual(PenAssetContract.remainingLiquidHeight(initialFill: 0.6, progress: 0.5), 124.2, accuracy: 1e-9)
        XCTAssertEqual(PenAssetContract.minimumTouchTarget, 44)
    }

    @MainActor
    func testIntensityControlStyleDelegatesTimingToDomainProfile() {
        let profile = IntensityControlStyle.profile(for: .three)

        XCTAssertEqual(profile.initialFill, 1)
        XCTAssertEqual(profile.durationMilliseconds, 1800)
        XCTAssertEqual(profile.progressPulseCount, 3)
    }

    func testTypographyUsesSemanticDynamicTypeStyles() throws {
        let source = try String(
            contentsOf: workspaceRoot.appendingPathComponent("iOSApp/Maeumjaro/DesignSystem/DesignTokens.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(source.contains(".system(size:"))
        for style in [".system(.title,", ".system(.title3,", ".system(.body,", ".system(.subheadline,", ".system(.caption,"] {
            XCTAssertTrue(source.contains(style), style)
        }
    }

    func testForbiddenScannerDetectsMutationButAllowsNeutralTerms() {
        XCTAssertEqual(BrandSafetyPolicy.forbiddenTerms(in: "치료"), ["치료"])
        XCTAssertTrue(BrandSafetyPolicy.forbiddenTerms(in: "요약").isEmpty)
        XCTAssertTrue(BrandSafetyPolicy.forbiddenTerms(in: "진단·치료·의학적 조언을 제공하지 않아요.").isEmpty)
        XCTAssertFalse(BrandSafetyPolicy.forbiddenTerms(in: "진단·치료·의학적 조언을 제공합니다.").isEmpty)
        XCTAssertEqual(
            BrandSafetyPolicy.forbiddenTerms(in: "가상 앱 안의 연출 자기조절 의식 패턴 기록"),
            []
        )
    }

    func testProductionSwiftSourcesContainNoForbiddenUserVisibleTerms() throws {
        let sourceRoot = workspaceRoot.appendingPathComponent("iOSApp/Maeumjaro")
        let files = swiftFiles(under: sourceRoot)
        var violations: [String] = []
        for file in files {
            let terms = BrandSafetyPolicy.forbiddenTerms(
                in: try String(contentsOf: file, encoding: .utf8)
            )
            violations += terms.map { "\(file.path):\($0)" }
        }

        XCTAssertTrue(violations.isEmpty, violations.joined(separator: ", "))
    }

    func testAssetManifestContainsEveryReleaseAssetWithProvenanceAndReviewStages() throws {
        let manifest = try loadManifest()
        let expectedIDs: Set<String> = [
            "AppIcon",
            "PenLocked",
            "PenReady",
            "PenComplete",
            "PenRingLocked",
            "PenRingReady",
            "PenWindowEmpty",
            "PenLiquidFull",
            "RitualCompleteV1"
        ]

        XCTAssertEqual(Set(manifest.assets.map(\.assetID)), expectedIDs)
        XCTAssertEqual(manifest.assets.count, expectedIDs.count)
        for asset in manifest.assets {
            XCTAssertFalse(asset.assetID.isEmpty)
            XCTAssertFalse(asset.version.isEmpty)
            XCTAssertFalse(asset.authoringTool.isEmpty)
            XCTAssertFalse(asset.license.isEmpty)
            XCTAssertFalse(asset.createdAt.isEmpty)
            XCTAssertEqual(asset.implementationReviewStatus, "passed")
            XCTAssertEqual(asset.releaseReviewStatus, "pending")
            XCTAssertTrue(asset.sha256.isSHA256)
            XCTAssertTrue(asset.sourceSha256.isSHA256)
            XCTAssertTrue(workspaceRoot.appendingPathComponent(asset.runtimePath).isRegularFile)
        }
    }

    func testOriginalPenAllowlistUsesIntentionalByteIdenticalCopies() throws {
        let manifest = try loadManifest()
        let entries = Dictionary(uniqueKeysWithValues: manifest.assets.map { ($0.assetID, $0) })
        let expected: [String: (source: String, runtime: String)] = [
            "PenLocked": (
                "assets/maeumjaro_pen/maeumjaro_pen_2d_locked.png",
                "iOSApp/Maeumjaro/Resources/Assets.xcassets/PenLocked.imageset/pen-locked.png"
            ),
            "PenReady": (
                "assets/maeumjaro_pen/maeumjaro_pen_2d_ready.png",
                "iOSApp/Maeumjaro/Resources/Assets.xcassets/PenReady.imageset/pen-ready.png"
            ),
            "PenComplete": (
                "assets/maeumjaro_pen/maeumjaro_pen_2d_complete.png",
                "iOSApp/Maeumjaro/Resources/Assets.xcassets/PenComplete.imageset/pen-complete.png"
            ),
            "PenRingLocked": (
                "assets/maeumjaro_pen/maeumjaro_pen_2d_ring_locked.png",
                "iOSApp/Maeumjaro/Resources/Assets.xcassets/PenRingLocked.imageset/pen-ring-locked.png"
            ),
            "PenRingReady": (
                "assets/maeumjaro_pen/maeumjaro_pen_2d_ring_ready.png",
                "iOSApp/Maeumjaro/Resources/Assets.xcassets/PenRingReady.imageset/pen-ring-ready.png"
            ),
            "PenWindowEmpty": (
                "assets/maeumjaro_pen/maeumjaro_pen_2d_window_empty.png",
                "iOSApp/Maeumjaro/Resources/Assets.xcassets/PenWindowEmpty.imageset/pen-window-empty.png"
            ),
            "PenLiquidFull": (
                "assets/maeumjaro_pen/maeumjaro_pen_2d_liquid_full.png",
                "iOSApp/Maeumjaro/Resources/Assets.xcassets/PenLiquidFull.imageset/pen-liquid-full.png"
            )
        ]

        XCTAssertEqual(Set(expected.keys), Set(PenAssetID.allCases.map(\.rawValue)))
        let docsHashes = try sha256s(under: workspaceRoot.appendingPathComponent("docs"))
        for (assetID, paths) in expected {
            let sourceURL = workspaceRoot.appendingPathComponent(paths.source)
            let runtimeURL = workspaceRoot.appendingPathComponent(paths.runtime)
            let sourceHash = try sha256(of: sourceURL)
            let runtimeHash = try sha256(of: runtimeURL)

            XCTAssertEqual(sourceHash, runtimeHash, assetID)
            XCTAssertEqual(entries[assetID]?.sourceSha256, sourceHash, assetID)
            XCTAssertEqual(entries[assetID]?.sha256, runtimeHash, assetID)
            XCTAssertFalse(docsHashes.contains(sourceHash), assetID)
        }
    }

    private func loadManifest() throws -> AssetManifest {
        let url = workspaceRoot.appendingPathComponent("iOSApp/Brand/AssetManifest.json")
        return try JSONDecoder().decode(AssetManifest.self, from: Data(contentsOf: url))
    }

    private func swiftFiles(under root: URL) -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .nameKey]
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles]
        )
        return (enumerator?.compactMap { item -> URL? in
            guard let file = item as? URL, file.pathExtension == "swift" else { return nil }
            return file
        } ?? [])
    }

    private func sha256(of url: URL) throws -> String {
        SHA256.hash(data: try Data(contentsOf: url))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func sha256s(under root: URL) throws -> Set<String> {
        let enumerator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)
        var hashes: Set<String> = []
        guard let enumerator else { return hashes }
        for case let file as URL in enumerator {
            guard file.isRegularFile else { continue }
            hashes.insert(try sha256(of: file))
        }
        return hashes
    }

    private var workspaceRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private enum BrandSafetyPolicy {
    private static let forbidden: [String] = [
        "약물", "의약품", "치료", "처방", "복용량", "용량", "칼로리", "체중", "식욕", "의지력",
        "효능", "진단", "약", "drug", "medicine", "treatment", "dosage", "efficacy", "diagnosis",
        "weight loss", "streak"
    ]

    static func forbiddenTerms(in text: String) -> [String] {
        let reviewedText = text
            .replacingOccurrences(of: "진단·치료·의학적 조언을 제공하지 않아요.", with: "")
            .replacingOccurrences(of: "진단, 치료, 의학적 조언을 제공하지 않으며 어떤 결과도 보장하지 않아요.", with: "")
        return forbidden.filter { term in
            if term == "약" {
                return reviewedText.range(of: "(?<![가-힣])약(?![가-힣])", options: .regularExpression) != nil
            }
            return reviewedText.localizedCaseInsensitiveContains(term)
        }
    }
}

private struct AssetManifest: Decodable {
    let assets: [AssetManifestEntry]
}

private struct AssetManifestEntry: Decodable {
    let assetID: String
    let version: String
    let runtimePath: String
    let authoringTool: String
    let createdAt: String
    let license: String
    let sourceSha256: String
    let sha256: String
    let implementationReviewStatus: String
    let releaseReviewStatus: String
}

private extension String {
    var isSHA256: Bool {
        count == 64 && allSatisfy { $0.isHexDigit }
    }
}

private extension URL {
    var isRegularFile: Bool {
        (try? resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    }
}
