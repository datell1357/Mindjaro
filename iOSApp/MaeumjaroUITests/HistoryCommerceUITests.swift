import XCTest

/// Focused history-detail and commerce failure coverage. Each test uses a
/// unique fixture namespace; no production store or data is touched.
@MainActor
final class HistoryCommerceUITests: XCTestCase {
    private let bundleID = "com.yeoreum.maeumjaro"
    private var app: XCUIApplication?

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(_ fixture: String, id: UUID = UUID()) -> XCUIApplication {
        let application = XCUIApplication(bundleIdentifier: bundleID)
        application.launchArguments += ["-MaeumjaroFixtureID", id.uuidString, "-MaeumjaroFixture", fixture]
        application.launch()
        app = application
        return application
    }

    @discardableResult
    private func completeOnboarding(_ app: XCUIApplication) -> Bool {
        let next = app.buttons["onboarding-next"]
        guard require(next) else { return false }
        next.tap()
        for _ in 0..<4 {
            let step = app.buttons["onboarding-next"]
            guard require(step) else { return false }
            step.tap()
        }
        if app.buttons["나중에"].waitForExistence(timeout: 2) {
            app.buttons["나중에"].tap()
        } else {
            let finish = app.buttons["완료"]
            guard require(finish) else { return false }
            finish.tap()
        }
        return require(app.tabBars.buttons["기록"])
    }

    @discardableResult
    private func require(_ element: XCUIElement, timeout: TimeInterval = 8) -> Bool {
        guard element.waitForExistence(timeout: timeout) else {
            if let app {
                let attachment = XCTAttachment(string: app.debugDescription)
                attachment.name = "history-commerce-missing-element"
                attachment.lifetime = .keepAlways
                add(attachment)
            }
            XCTFail("Required UI element did not appear")
            return false
        }
        return true
    }

    private func openFirstSeededDate(_ app: XCUIApplication) -> XCUIElement? {
        let date = app.buttons.matching(
            NSPredicate(format: "label MATCHES %@", "[0-9]{4}-[0-9]{2}-[0-9]{2}")
        ).firstMatch
        guard require(date) else { return nil }
        date.tap()
        guard require(app.buttons["기록 메뉴"]) else { return nil }
        return date
    }

    private func detailCount(_ app: XCUIApplication, _ value: String) -> XCUIElement {
        app.staticTexts["기록, \(value)"]
    }

    func testHistoryIndividualDeleteCancelAndConfirmPersistsAfterRelaunch() {
        let fixtureID = UUID()
        let app = launch("pro-boundary", id: fixtureID)
        require(app.tabBars.buttons["기록"])

        guard let originalDate = openFirstSeededDate(app) else { return }
        let originalDateLabel = originalDate.label
        let initial = detailCount(app, "1회")
        guard require(initial) else { return }

        // Cancel the individual delete alert and prove the event remains.
        app.buttons["기록 메뉴"].tap()
        let deleteMenuItem = app.buttons["삭제"]
        guard require(deleteMenuItem) else { return }
        deleteMenuItem.tap()
        let cancel = app.alerts.buttons["취소"]
        guard require(cancel) else { return }
        cancel.tap()
        XCTAssertTrue(initial.waitForExistence(timeout: 3), "Cancel must preserve the detail count")

        // Confirm deletion of one event and assert the detail count decrements.
        app.buttons["기록 메뉴"].tap()
        guard require(app.buttons["삭제"]) else { return }
        app.buttons["삭제"].tap()
        let alertDelete = app.alerts.buttons["삭제"]
        guard require(alertDelete) else { return }
        alertDelete.tap()
        require(app.tabBars.buttons["기록"], timeout: 5)
        let todayCount = app.staticTexts.matching(NSPredicate(format: "label == %@ AND value == %@", "오늘 기록", "0회")).firstMatch
        guard require(todayCount) else { return }
        XCTAssertFalse(app.buttons[originalDateLabel].exists, "Deleted date must leave the recent-record list")

        app.terminate()
        app.launch()
        require(app.tabBars.buttons["기록"])
        guard require(todayCount) else { return }
        XCTAssertFalse(app.buttons[originalDateLabel].exists, "The deleted row must not return after relaunch")
    }

    func testOfflinePaywallReportsStoreFailureAndRemainsFree() {
        let app = launch("offline")
        guard completeOnboarding(app) else { return }
        require(app.tabBars.buttons["설정"])
        app.tabBars.buttons["설정"].tap()
        let pro = app.buttons["Pro 기능 보기"]
        for _ in 0..<8 where !pro.isHittable { app.swipeUp() }
        guard require(pro) else { return }
        pro.tap()
        require(app.navigationBars["Pro"])
        let unavailable = app.staticTexts["스토어를 확인하지 못했어요."]
        guard require(unavailable, timeout: 8) else { return }
        let purchase = app.buttons["구매하기"]
        guard require(purchase) else { return }
        XCTAssertFalse(purchase.isEnabled, "Store failure must not enable purchase")

        app.buttons["구매 복원"].tap()
        guard require(app.staticTexts["복원할 Pro 구매를 확인하지 못했어요."]) else { return }
        XCTAssertFalse(purchase.isEnabled, "Failed restore must remain free")
    }
}
