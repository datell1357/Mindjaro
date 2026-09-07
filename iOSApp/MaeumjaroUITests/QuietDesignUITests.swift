import XCTest

/// Focused regression coverage for the quiet two-tab shell and pen-led ritual.
/// Each test gets an isolated empty fixture so completion counts are deterministic.
@MainActor
final class QuietDesignUITests: XCTestCase {
    private let bundleID = "com.yeoreum.maeumjaro"

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launchEmpty() -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: bundleID)
        app.launchArguments += [
            "-MaeumjaroFixtureID", UUID().uuidString,
            "-MaeumjaroFixture", "empty"
        ]
        app.launch()
        return app
    }

    @discardableResult
    private func require(_ element: XCUIElement, in app: XCUIApplication, name: String) -> Bool {
        guard element.waitForExistence(timeout: 8) else {
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "quiet-design-missing-\(name)"
            tree.lifetime = .keepAlways
            add(tree)
            XCTFail("Missing UI element: \(name)")
            return false
        }
        return true
    }

    @discardableResult
    private func completeOnboarding(_ app: XCUIApplication) -> Bool {
        let next = app.buttons["onboarding-next"]
        guard require(next, in: app, name: "onboarding-next") else { return false }
        next.tap()
        for _ in 0..<4 {
            let step = app.buttons["onboarding-next"]
            guard require(step, in: app, name: "onboarding-step") else { return false }
            step.tap()
        }
        if app.buttons["나중에"].waitForExistence(timeout: 2) {
            app.buttons["나중에"].tap()
        } else {
            let finish = app.buttons["완료"]
            guard require(finish, in: app, name: "onboarding-finish") else { return false }
            finish.tap()
        }
        return require(app.tabBars.buttons["기록"], in: app, name: "history-tab")
    }

    private func openRitual(_ app: XCUIApplication) -> XCUIElement? {
        let pen = app.buttons["ritual-start"]
        guard require(pen, in: app, name: "ritual-start") else { return nil }
        pen.tap()
        let canvas = app.otherElements["ritual-canvas"]
        guard require(canvas, in: app, name: "ritual-canvas") else { return nil }
        return canvas
    }

    private func unlock(_ canvas: XCUIElement) {
        let left = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let right = left.withOffset(CGVector(dx: 90, dy: 0))
        left.press(forDuration: 0.05, thenDragTo: right,
                   withVelocity: XCUIGestureVelocity.default, thenHoldForDuration: 0)
    }

    private func todayCount(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "오늘 기록")
        ).firstMatch
    }

    func testQuietHomeHasPenOnlyShellAndExpectedNavigation() {
        let app = launchEmpty()
        guard completeOnboarding(app) else { return }

        XCTAssertTrue(app.buttons["ritual-start"].exists)
        XCTAssertTrue(app.tabBars.buttons["기록"].exists)
        XCTAssertTrue(app.buttons["settings-open"].exists)
        XCTAssertEqual(app.buttons["settings-open"].label, "설정")
    }

    func testQuietRitualCanvasFillsScreenWithoutCoveringCloseControl() {
        let app = launchEmpty()
        guard completeOnboarding(app) else { return }

        let start = app.buttons["ritual-start"]
        guard require(start, in: app, name: "ritual-start-geometry") else { return }
        XCTAssertTrue(start.isHittable)
        guard let canvas = openRitual(app) else { return }
        let close = app.buttons["ritual-close"]
        guard require(close, in: app, name: "ritual-close-geometry") else { return }

        let lockedFrame = canvas.frame
        XCTAssertGreaterThan(
            lockedFrame.height,
            app.frame.height * 0.60,
            "The ritual pen canvas should occupy most of the available screen height"
        )
        XCTAssertFalse(
            lockedFrame.intersects(close.frame),
            "The close control must remain outside the pen canvas"
        )

        unlock(canvas)
        let ready = NSPredicate(format: "value CONTAINS %@", "준비됨")
        expectation(for: ready, evaluatedWith: canvas)
        waitForExpectations(timeout: 3)
        let unlockedFrame = canvas.frame
        XCTAssertLessThan(abs(unlockedFrame.minX - lockedFrame.minX), 2)
        XCTAssertLessThan(abs(unlockedFrame.minY - lockedFrame.minY), 2)
        XCTAssertLessThan(abs(unlockedFrame.width - lockedFrame.width), 2)
        XCTAssertLessThan(abs(unlockedFrame.height - lockedFrame.height), 2)
    }

    func testQuietRitualCompletionOffersRecordsAndRecordsExactlyOnce() {
        let app = launchEmpty()
        guard completeOnboarding(app), let canvas = openRitual(app) else { return }

        unlock(canvas)
        let ready = NSPredicate(format: "value CONTAINS %@", "준비됨")
        expectation(for: ready, evaluatedWith: canvas)
        waitForExpectations(timeout: 3)
        XCTAssertTrue((canvas.value as? String)?.contains("준비됨") == true, "A horizontal swipe must unlock the pen before holding")
        let unlockedScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        unlockedScreenshot.name = "quiet-after-unlock-rendered"
        unlockedScreenshot.lifetime = .keepAlways
        add(unlockedScreenshot)
        let progress = app.descendants(matching: .any)["ritual-progress"]
        guard require(progress, in: app, name: "ritual-progress") else { return }
        let unlocked = XCTAttachment(string: app.debugDescription)
        unlocked.name = "quiet-after-unlock"
        unlocked.lifetime = .keepAlways
        add(unlocked)
        canvas.press(forDuration: 2.4)

        guard require(app.buttons["기록 보기"], in: app, name: "records-action-after-completion") else { return }
        guard require(app.buttons["다시 실행"], in: app, name: "restart-action-after-completion") else { return }
        let completedScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        completedScreenshot.name = "quiet-after-completion-rendered"
        completedScreenshot.lifetime = .keepAlways
        add(completedScreenshot)
        XCTAssertTrue(app.images["기록 저장됨"].exists || app.otherElements["기록 저장됨"].exists)

        app.buttons["기록 보기"].tap()
        guard require(app.tabBars.buttons["기록"], in: app, name: "records-after-completion") else { return }
        let count = todayCount(app)
        guard require(count, in: app, name: "today-record-count") else { return }
        XCTAssertEqual(count.value as? String, "1회")
    }

    func testQuietRitualCloseCancelsWithoutRecording() {
        let app = launchEmpty()
        guard completeOnboarding(app), let canvas = openRitual(app) else { return }

        unlock(canvas)
        canvas.press(forDuration: 0.25)
        let close = app.buttons["ritual-close"]
        guard require(close, in: app, name: "ritual-close") else { return }
        close.tap()
        guard require(app.tabBars.buttons["기록"], in: app, name: "history-after-close") else { return }
        app.tabBars.buttons["기록"].tap()
        let count = todayCount(app)
        guard require(count, in: app, name: "today-count-after-close") else { return }
        XCTAssertEqual(count.value as? String, "0회")
    }
}
