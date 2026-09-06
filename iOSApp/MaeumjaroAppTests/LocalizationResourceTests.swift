import Foundation
import XCTest
@testable import Maeumjaro

final class LocalizationResourceTests: XCTestCase {
    func testKoreanCatalogIsCompiledIntoApplicationBundle() throws {
        let bundle = Bundle.main
        XCTAssertEqual(bundle.developmentLocalization, "ko")
        let path = try XCTUnwrap(bundle.path(forResource: "ko", ofType: "lproj"))
        let korean = try XCTUnwrap(Bundle(path: path))
        // A missing-key sentinel distinguishes compiled resources from key fallback.
        XCTAssertEqual(korean.localizedString(forKey: "의식 시작", value: "__MISSING__", table: "Localizable"), "의식 시작")
        XCTAssertEqual(korean.localizedString(forKey: "%lld회", value: "__MISSING__", table: "Localizable"), "%lld회")
        XCTAssertEqual(korean.localizedString(forKey: "%.1f회", value: "__MISSING__", table: "Localizable"), "%.1f회")
        XCTAssertEqual(korean.localizedString(forKey: "%lld회, 강도 합 %lld", value: "__MISSING__", table: "Localizable"), "%lld회, 강도 합 %lld")
        XCTAssertEqual(String(localized: "\(7)회"), "7회")
        XCTAssertEqual(korean.localizedString(forKey: "CFBundleDisplayName", value: "__MISSING__", table: "InfoPlist"), "마음자로")
    }
}
