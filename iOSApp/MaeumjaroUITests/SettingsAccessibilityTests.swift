import XCTest

/// Accessibility coverage for the real Settings and Data Management sheets.
/// The Pro-boundary fixture is isolated by a fresh UUID for every run.
@MainActor
final class SettingsAccessibilityTests: XCTestCase {
    private let bundleID = "com.yeoreum.maeumjaro"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(fixtureID: UUID, maximumType: Bool = true) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: bundleID)
        app.launchArguments += [
            "-MaeumjaroFixtureID", fixtureID.uuidString,
            "-MaeumjaroFixture", "pro-boundary"
        ]
        if maximumType {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        app.launch()
        return app
    }

    @discardableResult
    private func require(_ element: XCUIElement, in app: XCUIApplication, _ name: String, timeout: TimeInterval = 8) -> Bool {
        guard element.waitForExistence(timeout: timeout) else {
            attachSurface("missing-\(name)", from: app)
            XCTFail("Missing UI element: \(name)")
            return false
        }
        return true
    }

    private func scrollIntoView(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 10) {
        for _ in 0..<maxSwipes where !element.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(element.isHittable, "Element remains unreachable: \(element.identifier)")
    }

    private func attachSurface(_ name: String, from element: XCUIElement) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "\(name)-screenshot"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let tree = XCTAttachment(string: element.debugDescription)
        tree.name = "\(name)-tree"
        tree.lifetime = .keepAlways
        add(tree)
    }

    func testMaximumDynamicTypeSettingsAndDataManagementReachability() throws {
        let fixtureID = UUID()
        let fixture = XCTAttachment(string: fixtureID.uuidString)
        fixture.name = "settings-accessibility-fixture-id"
        fixture.lifetime = .keepAlways
        add(fixture)

        let app = launch(fixtureID: fixtureID)
        app.tabBars.buttons["홈"].tap()
        guard require(app.tabBars.buttons["설정"], in: app, "settings-open") else { return }
        app.tabBars.buttons["설정"].tap()

        let pro = app.buttons["Pro 기능 보기"]
        let dataManagement = app.buttons["데이터 관리"]
        scrollIntoView(pro, in: app)
        XCTAssertTrue(pro.isHittable, "Pro CTA must remain reachable at maximum Dynamic Type")
        scrollIntoView(dataManagement, in: app)
        XCTAssertTrue(dataManagement.isHittable, "Data Management CTA must remain reachable at maximum Dynamic Type")
        attachSurface("settings-maximum-dynamic-type", from: app)
        try app.performAccessibilityAudit(for: [.dynamicType, .textClipped])
    }

    func testMaximumDynamicTypeProPaywallReachability() throws {
        let fixtureID = UUID()
        let fixture = XCTAttachment(string: fixtureID.uuidString)
        fixture.name = "pro-accessibility-fixture-id"
        fixture.lifetime = .keepAlways
        add(fixture)

        let app = launch(fixtureID: fixtureID)
        app.tabBars.buttons["홈"].tap()
        guard require(app.tabBars.buttons["설정"], in: app, "settings-open") else { return }
        app.tabBars.buttons["설정"].tap()
        let pro = app.buttons["Pro 기능 보기"]
        scrollIntoView(pro, in: app)
        XCTAssertTrue(pro.isHittable, "Pro CTA must remain reachable at maximum Dynamic Type")
        pro.tap()
        guard require(app.navigationBars["Pro"], in: app, "pro-navigation") else { return }
        let purchase = app.buttons["구매하기"]
        let restore = app.buttons["구매 복원"]
        scrollIntoView(purchase, in: app)
        XCTAssertTrue(purchase.isHittable, "Purchase CTA must remain reachable at maximum Dynamic Type")
        scrollIntoView(restore, in: app)
        XCTAssertTrue(restore.isHittable, "Restore CTA must remain reachable at maximum Dynamic Type")
        attachSurface("pro-maximum-dynamic-type", from: app)
        try app.performAccessibilityAudit(for: [.dynamicType, .textClipped])
    }

    func testMaximumDynamicTypeDataManagementReachability() throws {
        try auditDataManagement(maximumType: true)
    }

    func testDataManagementSystemDynamicTypeWithoutLaunchOverride() throws {
        try auditDataManagement(maximumType: false)
    }

    private func auditDataManagement(maximumType: Bool) throws {
        let fixtureID = UUID()
        let fixture = XCTAttachment(string: fixtureID.uuidString)
        fixture.name = "data-management-accessibility-fixture-id-maximum-\(maximumType)"
        fixture.lifetime = .keepAlways
        add(fixture)

        let app = launch(fixtureID: fixtureID, maximumType: maximumType)
        app.tabBars.buttons["홈"].tap()
        guard require(app.tabBars.buttons["설정"], in: app, "settings-open") else { return }
        app.tabBars.buttons["설정"].tap()
        let dataManagement = app.buttons["데이터 관리"]
        scrollIntoView(dataManagement, in: app)
        XCTAssertTrue(dataManagement.isHittable, "Data Management CTA must remain reachable at maximum Dynamic Type")
        dataManagement.tap()
        let close = app.buttons["data-management-close"]
        guard require(close, in: app, "data-management-close") else { return }
        XCTAssertTrue(close.isHittable, "Data Management close CTA must remain reachable at maximum Dynamic Type")
        let export = app.buttons["내보내기"]
        let deleteAll = app.buttons["모든 기록 삭제"]
        scrollIntoView(export, in: app)
        XCTAssertTrue(export.isHittable, "Export CTA must remain reachable at maximum Dynamic Type")
        scrollIntoView(deleteAll, in: app)
        XCTAssertTrue(deleteAll.isHittable, "Delete CTA must remain reachable at maximum Dynamic Type")
        attachSurface("data-management-maximum-\(maximumType)", from: app)
        // Collect all audit failures instead of aborting on the first issue.
        // Returning false below still records each issue as a test failure.
        continueAfterFailure = true
        defer { continueAfterFailure = false }
        try app.performAccessibilityAudit(for: [.dynamicType, .textClipped]) { issue in
            let detail = XCTAttachment(string: "\(issue)\n\(issue.element?.debugDescription ?? "No element supplied")")
            detail.name = "data-management-audit-issue-element"
            detail.lifetime = .keepAlways
            self.add(detail)
            return false // Preserve every audit failure; only add diagnostic evidence.
        }
        attachSurface("data-management-after-audit-maximum-\(maximumType)", from: app)
        XCTAssertEqual(close.label, "닫기")
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 5))
    }
}
