import XCTest
import MaeumjaroShared

final class MaeumjaroWidgetScaffoldTests: XCTestCase {
    func testScaffoldTargetLoads() {
        XCTAssertEqual(AppIdentifiers.widgetKind, "MaeumjaroWidget")
    }
}
