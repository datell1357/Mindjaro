import Foundation
import XCTest

private final class WidgetLocalizationTestsBundleAnchor: NSObject {}

final class WidgetLocalizationTests: XCTestCase {
    func testCatalogIsAvailableInTestBundle() {
        let bundle = Bundle(for: WidgetLocalizationTestsBundleAnchor.self)
        XCTAssertEqual(String(localized: "widget.brand", bundle: bundle), "마음자로")
    }
}
