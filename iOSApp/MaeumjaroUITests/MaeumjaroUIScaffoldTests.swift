import XCTest

/// Simulator UI coverage for the real app shell and ritual. Every test uses a
/// unique fixture namespace so the suite never erases or reuses product data.
@MainActor
final class MaeumjaroRealUITests: XCTestCase {
    private let bundleID = "com.yeoreum.maeumjaro"
    private var currentApp: XCUIApplication?

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    private func launch(fixture: String = "ritual", fixtureID: UUID = UUID(), contentSizeCategory: String? = nil) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: bundleID)
        app.launchArguments += ["-MaeumjaroFixtureID", fixtureID.uuidString, "-MaeumjaroFixture", fixture]
        if let contentSizeCategory {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSizeCategory]
        }
        app.launch()
        currentApp = app
        return app
    }

    @discardableResult
    private func waitFor(_ element: XCUIElement, timeout: TimeInterval = 8) -> Bool {
        guard element.waitForExistence(timeout: timeout) else {
            if let currentApp {
                let appTree = XCTAttachment(string: currentApp.debugDescription)
                appTree.name = "ui-tree-missing-element"
                appTree.lifetime = .keepAlways
                add(appTree)
            }
            XCTFail("Required UI element did not appear")
            return false
        }
        return true
    }

    @discardableResult
    private func completeOnboarding(_ app: XCUIApplication) -> Bool {
        let start = app.buttons["onboarding-next"]
        guard waitFor(start) else { return false }
        start.tap()
        for _ in 0..<4 {
            let next = app.buttons["onboarding-next"]
            guard waitFor(next) else { return false }
            next.tap()
        }
        let later = app.buttons["나중에"]
        if later.waitForExistence(timeout: 2) { later.tap() }
        else {
            let finish = app.buttons["완료"]
            guard waitFor(finish) else { return false }
            finish.tap()
        }
        return waitFor(app.tabBars.buttons["기록"])
    }

    private func openRitual(_ app: XCUIApplication) -> XCUIElement? {
        // In the real TabView tree SwiftUI exposes the button's semantic label;
        // the parent tab carries history-tab and does not retain ritual-start.
        let start = app.buttons["ritual-start"]
        guard waitFor(start) else { return nil }
        start.tap()
        let canvas = app.otherElements["ritual-canvas"]
        guard waitFor(canvas) else { return nil }
        return canvas
    }

    private func unlock(_ canvas: XCUIElement) {
        let left = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.22, dy: 0.5))
        let right = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.78, dy: 0.5))
        left.press(forDuration: 0.05, thenDragTo: right, withVelocity: XCUIGestureVelocity.default, thenHoldForDuration: 0)
    }

    private func recordedCount(_ app: XCUIApplication) -> XCUIElement {
        let summary = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "오늘 기록")
        ).firstMatch
        waitFor(summary)
        return summary
    }

    private func progressPercent(_ element: XCUIElement) -> Int? {
        let accessibleText = [element.value as? String, element.label]
            .compactMap { $0 }
            .joined(separator: " ")
        guard let match = accessibleText.range(of: #"(\d+)퍼센트"#, options: .regularExpression) else {
            return nil
        }
        let digits = accessibleText[match].dropLast(3)
        return Int(digits)
    }

    @discardableResult
    private func scrollIntoView(_ element: XCUIElement, in app: XCUIApplication, maxSwipes: Int = 8) -> Bool {
        for _ in 0..<maxSwipes where !element.isHittable {
            app.swipeUp()
        }
        waitFor(element)
        XCTAssertTrue(element.isHittable, "Element remains offscreen: \(element.identifier)")
        return element.isHittable
    }

    @discardableResult
    private func openDataManagement(_ app: XCUIApplication) -> Bool {
        let data = app.buttons["데이터 관리"]
        guard scrollIntoView(data, in: app) else { return false }
        data.tap()
        return waitFor(app.buttons["data-management-close"])
    }

    func testOnboardingCompletesAndReachesTwoTabShell() {
        let app = launch(fixture: "empty")
        guard completeOnboarding(app) else { return }
        XCTAssertTrue(app.tabBars.buttons["기록"].exists)
        XCTAssertTrue(app.buttons["settings-open"].exists)
        XCTAssertFalse(app.alerts.firstMatch.exists, "Onboarding must not request a permission")
    }

    func testRitualSwipeHoldPauseResumeRecordsExactlyOnce() {
        let app = launch()
        guard completeOnboarding(app), let canvas = openRitual(app) else { return }
        unlock(canvas)
        let progress = app.descendants(matching: .any)["ritual-progress"]
        waitFor(progress)
        canvas.press(forDuration: 0.45)
        let pausedValue = progress.value as? String
        XCTAssertNotEqual(pausedValue, "진행률 0퍼센트", "A partial hold must advance the ritual")
        let remainsPaused = NSPredicate { object, _ in
            guard let element = object as? XCUIElement else { return false }
            return (element.value as? String) == pausedValue
        }
        expectation(for: remainsPaused, evaluatedWith: progress)
        waitForExpectations(timeout: 2)
        canvas.press(forDuration: 2.4)
        XCTAssertTrue(app.buttons["기록 보기"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["기록 보기"].exists)
        app.buttons["기록 보기"].tap()
        app.tabBars.buttons["기록"].tap()
        let count = recordedCount(app)
        XCTAssertEqual(count.value as? String, "1회", "Today summary must report one completed event")
        XCTAssertFalse(app.staticTexts["2회"].exists, "One session must emit one completion event")
    }

    /// Covers the paused lifecycle across Home/background and foreground
    /// reactivation. This intentionally does not cover an actively-held
    /// gesture crossing the background boundary (that requires device-level
    /// timing unavailable to this bounded UI regression).
    func testPausedRitualSurvivesBackgroundReactivationAndCloseDoesNotRecord() {
        let fixtureID = UUID()
        let fixture = XCTAttachment(string: fixtureID.uuidString)
        fixture.name = "paused-lifecycle-fixture-id"
        fixture.lifetime = .keepAlways
        add(fixture)

        let app = launch(fixtureID: fixtureID)
        guard completeOnboarding(app), let canvas = openRitual(app) else { return }
        unlock(canvas)

        let progress = app.descendants(matching: .any)["ritual-progress"]
        guard waitFor(progress) else { return }
        canvas.press(forDuration: 0.45)
        let partialProgress = NSPredicate { object, _ in
            guard let element = object as? XCUIElement,
                  let value = self.progressPercent(element) else { return false }
            return value > 0 && value < 100
        }
        expectation(for: partialProgress, evaluatedWith: progress)
        waitForExpectations(timeout: 5)
        guard let pausedValue = progressPercent(progress) else {
            XCTFail("Paused ritual must expose an accessible percentage")
            return
        }
        XCTAssertGreaterThan(pausedValue, 0)
        XCTAssertLessThan(pausedValue, 100)
        XCTAssertGreaterThan(pausedValue, 0, "A paused ritual must retain partial progress")

        let beforeBackground = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        beforeBackground.name = "paused-lifecycle-before-background"
        beforeBackground.lifetime = .keepAlways
        add(beforeBackground)
        let beforeTree = XCTAttachment(string: app.debugDescription)
        beforeTree.name = "paused-lifecycle-before-background-tree"
        beforeTree.lifetime = .keepAlways
        add(beforeTree)

        XCUIDevice.shared.press(.home)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5), "App must enter background")
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5), "Existing app instance must reactivate")
        guard waitFor(progress) else { return }
        guard let reactivatedValue = progressPercent(progress) else {
            XCTFail("Reactivated paused ritual must expose an accessible percentage")
            return
        }
        XCTAssertEqual(reactivatedValue, pausedValue, "Backgrounding must preserve the paused progress")
        XCTAssertLessThan(reactivatedValue, 100, "Paused ritual must not complete during backgrounding")
        XCTAssertFalse(app.buttons["기록 보기"].exists)

        let afterBackground = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        afterBackground.name = "paused-lifecycle-after-reactivation"
        afterBackground.lifetime = .keepAlways
        add(afterBackground)
        let afterTree = XCTAttachment(string: app.debugDescription)
        afterTree.name = "paused-lifecycle-after-reactivation-tree"
        afterTree.lifetime = .keepAlways
        add(afterTree)

        let close = app.buttons["ritual-close"]
        guard waitFor(close) else { return }
        close.tap()
        guard waitFor(app.tabBars.buttons["기록"]) else { return }
        XCTAssertEqual(recordedCount(app).value as? String, "0회")

        guard let reopenedCanvas = openRitual(app) else { return }
        let reopenedProgress = app.descendants(matching: .any)["ritual-progress"]
        guard waitFor(reopenedProgress) else { return }
        XCTAssertEqual(progressPercent(reopenedProgress), 0, "Closing a paused ritual must reset the next ritual")
        XCTAssertEqual(reopenedCanvas.value as? String, "진행률 0퍼센트")
    }

    func testRitualCancellationAndBackLeavesNoRecordedEvent() {
        let app = launch()
        guard completeOnboarding(app), let canvas = openRitual(app) else { return }
        unlock(canvas)
        canvas.press(forDuration: 0.25)
        let close = app.buttons["ritual-close"]
        waitFor(close)
        close.tap()
        waitFor(app.tabBars.buttons["기록"])
        XCTAssertEqual(recordedCount(app).value as? String, "0회", "Cancellation must not create a record")
    }

    func testSystemDeepLinksRejectInvalidHostIgnoreIntensityAndRecordSources() {
        let fixtureID = UUID()
        let fixture = XCTAttachment(string: fixtureID.uuidString)
        fixture.name = "deep-link-fixture-id"
        fixture.lifetime = .keepAlways
        add(fixture)
        let app = launch(fixture: "empty", fixtureID: fixtureID)
        guard completeOnboarding(app) else { return }
        XCTAssertEqual(recordedCount(app).value as? String, "0회")
        app.open(URL(string: "maeumjaro://other?source=app")!)
        XCTAssertTrue(app.tabBars.buttons["기록"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["ritual-canvas"].exists)
        XCTAssertEqual(recordedCount(app).value as? String, "0회")
        for (source, count) in [("widget", "1회"), ("app", "2회")] {
            app.open(URL(string: "maeumjaro://inject?source=\(source)&intensity=1")!)
            let canvas = app.otherElements["ritual-canvas"]
            guard waitFor(canvas) else { return }
            XCTAssertEqual(canvas.label, "마음 정리 의식, 강도 3", "URL cannot override shared strength")
            unlock(canvas)
            canvas.press(forDuration: 2.4)
            guard waitFor(app.buttons["기록 보기"]) else { return }
            app.buttons["기록 보기"].tap()
            app.tabBars.buttons["기록"].tap()
            XCTAssertEqual(recordedCount(app).value as? String, count)
            let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screenshot.name = "deep-link-\(source)-completion"
            screenshot.lifetime = .keepAlways
            add(screenshot)
        }
    }

    func testHistoryAndRitualSystemDynamicTypeAudit() throws {
        let app = launch(fixture: "free-boundary")
        guard waitFor(app.tabBars.buttons["기록"]) else { return }
        try app.performAccessibilityAudit(for: [.dynamicType, .textClipped])
        guard let canvas = openRitual(app) else { return }
        XCTAssertTrue(canvas.isHittable)
        try app.performAccessibilityAudit(for: [.dynamicType, .textClipped])
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "ritual-after-system-dynamic-type-audit"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testCompletedRitualSystemDynamicTypeAuditAndRecordsAction() throws {
        let app = launch(fixture: "empty")
        guard completeOnboarding(app), let canvas = openRitual(app) else { return }
        unlock(canvas)
        canvas.press(forDuration: 2.4)
        guard waitFor(app.buttons["기록 보기"]) else { return }
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "completed-ritual-before-accessibility-audit"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        try app.performAccessibilityAudit(for: [.dynamicType, .textClipped])
        let records = app.buttons["기록 보기"]
        let completionScroll = app.scrollViews.firstMatch
        guard waitFor(completionScroll) else { return }
        completionScroll.swipeUp()
        XCTAssertTrue(records.isHittable)
        XCTAssertGreaterThanOrEqual(records.frame.minY, completionScroll.frame.minY)
        XCTAssertLessThanOrEqual(records.frame.maxY, completionScroll.frame.maxY,
                                 "Records button must be fully visible inside its scroll viewport")
        let visible = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        visible.name = "completed-ritual-records-button-after-scroll"
        visible.lifetime = .keepAlways
        add(visible)
        records.tap()
        app.tabBars.buttons["기록"].tap()
        XCTAssertEqual(recordedCount(app).value as? String, "1회")
    }

    func testMaximumDynamicTypeHistoryAndRitualReachability() {
        let app = launch(fixture: "free-boundary", contentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL")
        guard waitFor(app.tabBars.buttons["기록"]) else { return }
        for name in ["maximum-type-history", "maximum-type-ritual"] {
            if name == "maximum-type-ritual" {
                guard openRitual(app) != nil else { return }
            }
            let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screenshot.name = name
            screenshot.lifetime = .keepAlways
            add(screenshot)
            let tree = XCTAttachment(string: app.debugDescription)
            tree.name = "\(name)-tree"
            tree.lifetime = .keepAlways
            add(tree)
        }
        XCTAssertTrue(app.buttons["ritual-close"].isHittable)
        let progress = app.descendants(matching: .any)["ritual-progress"]
        for _ in 0..<8 where !progress.isHittable {
            // Scroll within the visible text region, outside the pen's gesture region.
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
            start.press(forDuration: 0.01, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2)))
        }
        XCTAssertTrue(progress.isHittable, "Progress must remain reachable at maximum Dynamic Type")
        let finalScreenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        finalScreenshot.name = "maximum-type-progress-after-scroll"
        finalScreenshot.lifetime = .keepAlways
        add(finalScreenshot)
    }

    func testRitualHorizontalThresholdVerticalRejectionAndRelockWithoutRecording() {
        let app = launch()
        guard completeOnboarding(app), let canvas = openRitual(app) else { return }
        func drag(dx: CGFloat, dy: CGFloat) {
            let start = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: dx, dy: dy)),
                        withVelocity: XCUIGestureVelocity.default, thenHoldForDuration: 0)
        }
        func assertHint(_ expected: String) {
            let expectedValue = "진행률 0퍼센트 · \(expected)"
            let state = NSPredicate(format: "value == %@", expectedValue)
            expectation(for: state, evaluatedWith: canvas)
            waitForExpectations(timeout: 3)
            XCTAssertEqual(canvas.value as? String, expectedValue)
            let attachment = XCTAttachment(string: app.debugDescription)
            attachment.name = "gesture-boundary-\(expected)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        let locked = "잠금"
        let ready = "준비됨"
        assertHint(locked)
        drag(dx: 44, dy: 0)
        assertHint(locked)
        drag(dx: 56, dy: 80)
        assertHint(locked)
        drag(dx: 56, dy: 0)
        assertHint(ready)
        // Directional movement before the 120 ms hold delay cancels the
        // pending hold. Movement after a hold starts is intentionally not a ring gesture.
        drag(dx: 0, dy: 80)
        assertHint(ready)
        // A fresh reverse pointer sequence relocks; neither ring gesture is a hold.
        drag(dx: -56, dy: 0)
        assertHint(locked)
        drag(dx: -56, dy: 0)
        assertHint(ready)
        app.buttons["ritual-close"].tap()
        guard waitFor(app.tabBars.buttons["기록"]) else { return }
        app.tabBars.buttons["기록"].tap()
        XCTAssertEqual(recordedCount(app).value as? String, "0회")
    }

    func testSettingsTogglePersistsAfterRelaunch() {
        let app = launch(fixture: "empty")
        guard completeOnboarding(app) else { return }
        app.tabBars.buttons["홈"].tap()
        app.buttons["settings-open"].tap()
        let sound = app.switches["소리"]
        waitFor(sound)
        let before = sound.value as? String
        // SwiftUI Form exposes the switch row as one element; the observed
        // native hit target is the trailing Toggle control.
        sound.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "settings-sound-after-toggle"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let changed = NSPredicate { object, _ in
            guard let element = object as? XCUIElement else { return false }
            return (element.value as? String) != before
        }
        expectation(for: changed, evaluatedWith: sound)
        waitForExpectations(timeout: 3)
        let after = sound.value as? String
        XCTAssertNotEqual(before, after, "The settings control must actually change state")
        app.terminate()
        app.launch()
        app.tabBars.buttons["홈"].tap()
        app.buttons["settings-open"].tap()
        let relaunchedSound = app.switches["소리"]
        waitFor(relaunchedSound)
        XCTAssertEqual(relaunchedSound.value as? String, after)
    }

    func testFreeBoundaryRendersThirtyDayListWithoutHeatmap() {
        let app = launch(fixture: "free-boundary")
        waitFor(app.tabBars.buttons["기록"])
        waitFor(app.staticTexts["최근 30일"])

        // FreeDailyListView exposes each date as a button label; SwiftUI's
        // accessibility query does not support a `hint` predicate key path.
        let dateRows = app.buttons.matching(
            NSPredicate(format: "label MATCHES %@", "[0-9]{4}-[0-9]{2}-[0-9]{2}")
        )
        XCTAssertGreaterThanOrEqual(dateRows.count, 30, "Free history must render the complete 30-day list")
        XCTAssertFalse(app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "히트맵 표시")
        ).firstMatch.exists, "Free history must not render the Pro heatmap control")
    }

    func testProBoundaryRendersHeatmapAndAnalytics() {
        let app = launch(fixture: "pro-boundary")
        waitFor(app.tabBars.buttons["기록"])
        let heatmap = app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "히트맵 표시")
        ).firstMatch
        waitFor(heatmap)
        waitFor(app.staticTexts["시간대 분포"])
        waitFor(app.staticTexts["요일 분포"])
        waitFor(app.staticTexts["강도 분포"])
        XCTAssertFalse(app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "상세 패턴 잠금")
        ).firstMatch.exists, "Verified Pro must render detailed analytics")
    }

    func testOfflineFixtureCanCompleteCoreRitualWithoutStoreKit() {
        let app = launch(fixture: "offline")
        guard completeOnboarding(app), let canvas = openRitual(app) else { return }
        unlock(canvas)
        canvas.press(forDuration: 2.4)

        XCTAssertTrue(app.buttons["기록 보기"].waitForExistence(timeout: 8))
        app.buttons["기록 보기"].tap()
        app.tabBars.buttons["기록"].tap()
        XCTAssertEqual(recordedCount(app).value as? String, "1회", "Offline StoreKit must not block the local core ritual")
    }

    func testProDataManagementShareCancellationDeletePathsAndRelaunch() {
        let fixtureID = UUID()
        let app = launch(fixture: "pro-boundary", fixtureID: fixtureID)
        waitFor(app.buttons["settings-open"])
        app.tabBars.buttons["홈"].tap()
        app.buttons["settings-open"].tap()
        guard openDataManagement(app) else { return }

        let forest = app.buttons["Forest Mist"]
        guard scrollIntoView(forest, in: app) else { return }
        forest.tap()
        XCTAssertTrue(forest.isSelected, "Verified Pro must select the chosen theme")

        // Exercise both supported exports. ShareLink is surfaced as an app
        // button; tapping 공유 opens the native activity UI.
        let format = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH %@", "형식,")
        ).firstMatch
        guard scrollIntoView(format, in: app) else { return }
        format.tap()
        let csv = app.buttons["CSV"]
        waitFor(csv)
        csv.tap()
        let export = app.buttons["내보내기"]
        guard scrollIntoView(export, in: app) else { return }
        export.tap()
        let csvShare = app.buttons["export-share"]
        guard waitFor(csvShare) else { return }
        csvShare.tap()
        let csvActivity = app.otherElements["ActivityListView"]
        guard waitFor(csvActivity, timeout: 5) else { return }
        guard waitFor(app.navigationBars["maeumjaro-history.csv"], timeout: 5) else { return }
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
        XCTAssertFalse(csvActivity.waitForExistence(timeout: 2), "CSV popover dismissal must cancel without sharing")
        let exportClose = app.buttons["export-close"]
        guard waitFor(exportClose) else { return }
        exportClose.tap()

        format.tap()
        app.buttons["JSON"].tap()
        export.tap()
        let jsonShare = app.buttons["export-share"]
        guard waitFor(jsonShare) else { return }
        jsonShare.tap()
        let jsonActivity = app.otherElements["ActivityListView"]
        guard waitFor(jsonActivity, timeout: 5) else { return }
        guard waitFor(app.navigationBars["maeumjaro-history.json"], timeout: 5) else { return }
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25)).tap()
        XCTAssertFalse(jsonActivity.waitForExistence(timeout: 2), "JSON popover dismissal must cancel without sharing")
        guard waitFor(exportClose) else { return }
        exportClose.tap()

        let deleteAll = app.buttons["모든 기록 삭제"]
        guard scrollIntoView(deleteAll, in: app) else { return }
        deleteAll.tap()
        // The confirmation popover has only the destructive action. Tapping
        // outside its observed frame dismisses it without deleting.
        let confirmDelete = app.buttons["삭제"]
        guard waitFor(confirmDelete) else { return }
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6)).tap()
        XCTAssertFalse(confirmDelete.waitForExistence(timeout: 2), "Outside tap must cancel deletion")
        let managementClose = app.buttons["data-management-close"]
        guard waitFor(managementClose) else { return }
        managementClose.tap()
        app.tabBars.buttons["기록"].tap()
        let seededDateRows = app.buttons.matching(
            NSPredicate(format: "label MATCHES %@", "[0-9]{4}-[0-9]{2}-[0-9]{2}")
        )
        XCTAssertGreaterThan(seededDateRows.count, 0, "Delete cancellation must preserve isolated fixture records")
        app.tabBars.buttons["홈"].tap()
        app.buttons["settings-open"].tap()
        guard openDataManagement(app) else { return }
        let deleteAllAgain = app.buttons["모든 기록 삭제"]
        guard scrollIntoView(deleteAllAgain, in: app) else { return }

        deleteAllAgain.tap()
        let confirm = app.buttons["삭제"]
        guard waitFor(confirm) else { return }
        confirm.tap()
        guard waitFor(app.staticTexts["모든 기록을 삭제했어요."]) else { return }
        guard waitFor(managementClose) else { return }
        managementClose.tap()

        app.terminate()
        app.launch()
        waitFor(app.buttons["settings-open"])
        XCTAssertFalse(app.buttons["완료"].exists, "Relaunch must remain past onboarding")
        app.tabBars.buttons["홈"].tap()
        app.buttons["settings-open"].tap()
        guard openDataManagement(app) else { return }
        let forestAfterRelaunch = app.buttons["Forest Mist"]
        guard scrollIntoView(forestAfterRelaunch, in: app) else { return }
        XCTAssertTrue(forestAfterRelaunch.isSelected, "Theme selection must survive relaunch")
        guard waitFor(managementClose) else { return }
        managementClose.tap()
        app.tabBars.buttons["기록"].tap()
        waitFor(app.staticTexts["아직 기록이 없어요. 오늘의 작은 선택을 남겨 보세요."])
    }
}
