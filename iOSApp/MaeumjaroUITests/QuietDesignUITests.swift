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

    private func launchEmpty(largeText: Bool = false) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: bundleID)
        app.launchArguments += [
            "-MaeumjaroFixtureID", UUID().uuidString,
            "-MaeumjaroFixture", "empty"
        ]
        if largeText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
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
        let phrase = app.staticTexts["completion-phrase"]
        guard require(phrase, in: app, name: "completion-phrase") else { return }
        XCTAssertFalse(phrase.label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        XCTAssertTrue(phrase.isHittable, "The quote must be visible immediately without scrolling past the pen")
        XCTAssertTrue(app.buttons["기록 보기"].isHittable)
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
        app.tabBars.buttons["홈"].tap()
        app.buttons["settings-open"].tap()
        let total = app.staticTexts["settings-weekly-total"]
        guard require(total, in: app, name: "weekly-total-after-completion") else { return }
        XCTAssertEqual(total.label, "총 1회")
        let chart = app.descendants(matching: .any)["settings-weekly-chart"]
        guard require(chart, in: app, name: "weekly-chart-after-completion") else { return }
        XCTAssertTrue((chart.value as? String)?.contains("1회") == true)
        let chartScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        chartScreenshot.name = "settings-after-completion"
        chartScreenshot.lifetime = .keepAlways
        add(chartScreenshot)
    }

    func testOnboardingCentersContentAndLargeTextRemainsNavigable() {
        let app = launchEmpty()
        let title = app.staticTexts["마음자로"]
        guard require(title, in: app, name: "onboarding-title") else { return }
        let message = app.staticTexts["잠깐 멈추고 지금의 선택을 돌아보는 짧은 비의료적 자기조절 의식이에요."]
        guard require(message, in: app, name: "onboarding-message") else { return }
        let contentFrame = title.frame.union(message.frame)
        XCTAssertLessThan(abs(contentFrame.midY - app.frame.midY), app.frame.height * 0.10)
        let centered = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        centered.name = "onboarding-centered"
        centered.lifetime = .keepAlways
        add(centered)
        app.terminate()
        let largeApp = launchEmpty(largeText: true)
        XCTAssertTrue(completeOnboarding(largeApp))
    }

    func testSettingsChartUsesSevenDaysOfStoredRecords() {
        let app = XCUIApplication(bundleIdentifier: bundleID)
        app.launchArguments = ["-MaeumjaroFixtureID", UUID().uuidString, "-MaeumjaroFixture", "free-boundary"]
        app.launch()
        guard require(app.buttons["settings-open"], in: app, name: "settings-open-populated") else { return }
        app.buttons["settings-open"].tap()
        let total = app.staticTexts["settings-weekly-total"]
        guard require(total, in: app, name: "weekly-total-populated") else { return }
        XCTAssertEqual(total.label, "총 7회", "Exclude the older 24 records from the weekly chart")
        let chart = app.descendants(matching: .any)["settings-weekly-chart"]
        guard require(chart, in: app, name: "weekly-chart-populated") else { return }
        XCTAssertEqual((chart.value as? String)?.components(separatedBy: ", ").count, 7)
        XCTAssertTrue(chart.isHittable)
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
