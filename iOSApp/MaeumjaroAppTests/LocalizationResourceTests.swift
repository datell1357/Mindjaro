import Foundation
import XCTest
@testable import Maeumjaro
@testable import MaeumjaroIntents

final class LocalizationResourceTests: XCTestCase {
    func testIntentMetadataIsCompiledIntoPackageBundle() {
        let expected = [
            "intent.title": "강도 변경",
            "intent.description": "마음자로 위젯의 현재 강도를 변경합니다.",
            "intent.parameter.target": "목표 강도",
            "intent.parameter.delta": "강도 변경량"
        ]
        for (key, value) in expected {
            XCTAssertEqual(Bundle.module.localizedString(forKey: key, value: "__MISSING__", table: "Localizable"), value)
        }
        XCTAssertEqual(String(localized: SetStrengthIntent.title), "강도 변경")
    }

    func testKoreanCatalogIsCompiledIntoApplicationBundle() throws {
        let bundle = Bundle.main
        XCTAssertEqual(bundle.developmentLocalization, "ko")
        let path = try XCTUnwrap(bundle.path(forResource: "ko", ofType: "lproj"))
        let korean = try XCTUnwrap(Bundle(path: path))
        // A missing-key sentinel distinguishes compiled resources from key fallback.
        XCTAssertEqual(korean.localizedString(forKey: "의식 시작", value: "__MISSING__", table: "Localizable"), "의식 시작")
        XCTAssertEqual(korean.localizedString(forKey: "1. 시작을 누르고\n2. 화면을 가로로 천천히 쓸어 흐름을 따라가고\n3. 새로 가볍게 눌러 잠깐 멈췄다가 놓은 뒤 기록을 확인해요.", value: "__MISSING__", table: "Localizable"), "1. 시작을 누르고\n2. 화면을 가로로 천천히 쓸어 흐름을 따라가고\n3. 새로 가볍게 눌러 잠깐 멈췄다가 놓은 뒤 기록을 확인해요.")
        XCTAssertEqual(korean.localizedString(forKey: "Quiet Ivory", value: "__MISSING__", table: "Localizable"), "Quiet Ivory")
        XCTAssertEqual(korean.localizedString(forKey: "Midnight Ink", value: "__MISSING__", table: "Localizable"), "Midnight Ink")
        XCTAssertEqual(korean.localizedString(forKey: "Forest Mist", value: "__MISSING__", table: "Localizable"), "Forest Mist")
        XCTAssertEqual(korean.localizedString(forKey: "%lld회", value: "__MISSING__", table: "Localizable"), "%lld회")
        XCTAssertEqual(korean.localizedString(forKey: "%.1f회", value: "__MISSING__", table: "Localizable"), "%.1f회")
        XCTAssertEqual(korean.localizedString(forKey: "%lld회, 강도 합 %lld", value: "__MISSING__", table: "Localizable"), "%lld회, 강도 합 %lld")
        XCTAssertEqual(String(localized: "\(7)회"), "7회")
        XCTAssertEqual(korean.localizedString(forKey: "CFBundleDisplayName", value: "__MISSING__", table: "InfoPlist"), "마음자로")
    }
}
