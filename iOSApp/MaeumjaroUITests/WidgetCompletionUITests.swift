import XCTest

/// End-to-end coverage for a completion started from an already-installed
/// Maeumjaro Home Screen widget. The test uses one fresh fixture namespace and
/// never edits, removes, or rearranges Home Screen widgets.
@MainActor
final class WidgetCompletionUITests: XCTestCase {
    private let appBundleID = "com.yeoreum.maeumjaro"
    private let widgetLabelCandidates = ["마음자로 오늘 위젯", "마음자로 강도 선택 위젯"]

    private func launchFixture(fixtureID: UUID = UUID(), armCold: Bool = false) -> XCUIApplication {
        let app = XCUIApplication(bundleIdentifier: appBundleID)
        app.launchArguments += [
            "-MaeumjaroFixtureID", fixtureID.uuidString,
            "-MaeumjaroFixture", "ritual"
        ]
        if armCold {
            app.launchArguments += ["-MaeumjaroArmColdWidgetFixture"]
        }
        app.launch()
        return app
    }

    private func attachTree(_ name: String, from element: XCUIElement) {
        let attachment = XCTAttachment(string: element.debugDescription)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func addFixtureAttachment(_ fixtureID: UUID, name: String) {
        let attachment = XCTAttachment(string: fixtureID.uuidString)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @discardableResult
    private func waitFor(_ element: XCUIElement, _ message: String, timeout: TimeInterval = 8) -> Bool {
        guard element.waitForExistence(timeout: timeout) else {
            attachTree("missing-\(message)", from: element)
            XCTFail("Missing UI element: \(message)")
            return false
        }
        return true
    }

    private func completeOnboardingAtStrengthFive(_ app: XCUIApplication) {
        let start = app.buttons["onboarding-next"]
        guard waitFor(start, "onboarding start") else { return }
        start.tap()
        guard waitFor(app.buttons["onboarding-next"], "how-to-use next") else { return }
        app.buttons["onboarding-next"].tap()

        let intensity = app.buttons["onboarding-intensity-5"]
        guard waitFor(intensity, "onboarding intensity 5") else { return }
        intensity.tap()

        for _ in 0..<3 where app.buttons["onboarding-next"].waitForExistence(timeout: 1) {
            app.buttons["onboarding-next"].tap()
        }
        if app.buttons["나중에"].waitForExistence(timeout: 2) {
            app.buttons["나중에"].tap()
        } else {
            let finish = app.buttons["onboarding-finish"]
            guard waitFor(finish, "onboarding finish") else { return }
            finish.tap()
        }
        _ = waitFor(app.tabBars.buttons["기록"], "record tab")
    }

    @discardableResult
    private func completeCurrentRitual(_ app: XCUIApplication) -> Bool {
        let canvas = app.otherElements["ritual-canvas"]
        guard waitFor(canvas, "ritual canvas") else { return false }

        let left = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.22, dy: 0.5))
        let right = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.78, dy: 0.5))
        left.press(forDuration: 0.05, thenDragTo: right,
                   withVelocity: XCUIGestureVelocity.default, thenHoldForDuration: 0)
        canvas.press(forDuration: 3.4)
        return waitFor(app.staticTexts["의식 완료"], "ritual completion", timeout: 10)
    }

    private func tapWidgetStart(_ widget: XCUIElement) {
        let start = widget.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "시작")).firstMatch
        if start.waitForExistence(timeout: 1) {
            start.tap()
            return
        }
        // The provider's root accessibilityLabel collapses SwiftUI children on
        // this SpringBoard surface, so the Link is not exposed as a descendant.
        // Use the source layout as a semantic fallback: small places Start in
        // the bottom row; medium places it in the top-right HStack.
        let isMedium = widget.frame.width > widget.frame.height * 1.5
        let offset = isMedium
            ? CGVector(dx: 0.84, dy: 0.18)
            : CGVector(dx: 0.50, dy: 0.86)
        widget.coordinate(withNormalizedOffset: offset).tap()
    }

    private func findInstalledWidget(in springboard: XCUIApplication, medium: Bool) -> XCUIElement? {
        let icons = springboard.icons.matching(
            NSPredicate(format: "identifier == %@", "마음자로")
        )
        for page in 0..<4 {
            if let widget = (0..<icons.count).map({ icons.element(boundBy: $0) }).first(where: {
                $0.waitForExistence(timeout: 2)
                    && $0.frame.width > 150 && $0.frame.height > 150
                    && ($0.frame.width > $0.frame.height * 1.5) == medium
                    && $0.isHittable
            }) {
                return widget
            }
            if page < 3 { springboard.swipeLeft() }
        }
        return nil
    }

    /// Navigation-only cold launch check. Each size gets a fresh fixture so
    /// cold-consumption persistence cannot make this test order-dependent.
    func testBothWidgetSizesColdLaunchAndCancelWithoutAddingRecords() {
        continueAfterFailure = false
        for medium in [false, true] {
            let fixtureID = UUID()
            addFixtureAttachment(fixtureID, name: "cold-navigation-fixture-(medium)")
            let onboarding = launchFixture(fixtureID: fixtureID)
            completeOnboardingAtStrengthFive(onboarding)
            onboarding.terminate()
            XCTAssertTrue(onboarding.wait(for: .notRunning, timeout: 5))

            let app = launchFixture(fixtureID: fixtureID, armCold: true)
            guard waitFor(app.tabBars.buttons["기록"], "cold fixture history", timeout: 10) else { return }
            app.tabBars.buttons["기록"].tap()
            let today = app.descendants(matching: .any).matching(
                NSPredicate(format: "label == %@", "오늘 기록")
            ).firstMatch
            guard waitFor(today, "cold fixture baseline count") else { return }
            XCTAssertEqual(today.value as? String, "0회")
            app.terminate()
            XCTAssertTrue(app.wait(for: .notRunning, timeout: 5))
            XCUIDevice.shared.press(.home)
            let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
            springboard.activate()
            guard let widget = findInstalledWidget(in: springboard, medium: medium) else {
                attachTree("cold-widget-missing-medium-\(medium)", from: springboard)
                XCTFail("Required installed widget size missing")
                return
            }
            XCTAssertEqual(app.state, .notRunning)
            attachTree("cold-widget-before-start-medium-\(medium)", from: widget)
            tapWidgetStart(widget)
            XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
            guard waitFor(app.otherElements["ritual-canvas"], "cold widget ritual") else { return }
            let identity = app.descendants(matching: .any).matching(
                NSPredicate(format: "identifier == %@", "qa-fixture-identity")
            ).firstMatch
            guard waitFor(identity, "cold navigation fixture identity") else { return }
            guard identity.label == fixtureID.uuidString else {
                XCTFail("Cold navigation fixture identity mismatch: \(identity.label)")
                return
            }
            let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screenshot.name = "cold-widget-ritual-medium-\(medium)"
            screenshot.lifetime = .keepAlways
            add(screenshot)
            attachTree("cold-widget-ritual-tree-medium-\(medium)", from: app)
            let close = app.buttons["ritual-close"]
            guard waitFor(close, "cold ritual close") else { return }
            close.tap()
            guard waitFor(app.tabBars.buttons["기록"], "history after cancellation") else { return }
            XCTAssertEqual(app.descendants(matching: .any).matching(
                NSPredicate(format: "label == %@", "오늘 기록")
            ).firstMatch.value as? String, "0회")
        }
    }

    func testWidgetStartCompletesStrengthFiveAndUpdatesTodaySummary() {
        let app = launchFixture()
        completeOnboardingAtStrengthFive(app)
        // Keep the isolated fixture process alive: a system cold launch has no
        // fixture arguments and intentionally opens the production namespace.
        XCUIDevice.shared.press(.home)

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        springboard.activate()
        // The provider accessibility label is surfaced as a StaticText inside
        // SpringBoard's widget process. Select the enclosing Home Screen Icon
        // (identifier 마음자로, value 위젯) so its frame is the actual widget.
        let widgetIcons = springboard.icons.matching(
            NSPredicate(format: "identifier == %@ AND value == %@", "마음자로", "위젯")
        )
        let widget = (0..<widgetIcons.count).lazy
            .map { widgetIcons.element(boundBy: $0) }
            .first { $0.frame.width > 150 && $0.frame.height > 150 && $0.waitForExistence(timeout: 3) }
        guard let widget else {
            attachTree("springboard-widget-missing", from: springboard)
            XCTFail("No existing Maeumjaro small or medium widget was found on the Home Screen")
            return
        }
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "springboard-widget-before-start"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        attachTree("springboard-widget-before-start-tree", from: widget)

        tapWidgetStart(widget)

        let relaunched = XCUIApplication(bundleIdentifier: appBundleID)
        waitFor(relaunched, "app after widget start")
        // A cold deep-link launch currently has no fixture arguments. Fail
        // explicitly if it fell back to production instead of claiming E2E.
        if relaunched.buttons["onboarding-next"].waitForExistence(timeout: 2) {
            attachTree("widget-cold-launch-lost-fixture", from: relaunched)
            XCTFail("Widget cold launch lost the fixture namespace and entered onboarding")
            return
        }
        waitFor(relaunched.otherElements["ritual-canvas"], "widget-opened ritual canvas")
        guard completeCurrentRitual(relaunched) else { return }
        relaunched.buttons["기록 보기"].tap()
        waitFor(relaunched.staticTexts["오늘 기록"], "today record summary")
        XCTAssertEqual(
            relaunched.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "오늘 기록")).firstMatch.value as? String,
            "1회"
        )

        XCUIDevice.shared.press(.home)
        springboard.activate()
        let updatedWidget = (0..<widgetIcons.count).lazy
            .map { widgetIcons.element(boundBy: $0) }
            .first { $0.frame.width > 150 && $0.frame.height > 150 && $0.waitForExistence(timeout: 5) }
        guard let updatedWidget else {
            attachTree("springboard-widget-after-completion-missing", from: springboard)
            XCTFail("Maeumjaro widget disappeared after completion")
            return
        }
        waitFor(updatedWidget, "updated widget")
        // SpringBoard keeps the enclosing Icon's value as the generic string
        // "위젯". The provider's today summary is exposed by a descendant in
        // the widget process and can lag one timeline refresh after saving.
        let todayValue = updatedWidget.descendants(matching: .any).matching(
            NSPredicate(format: "value CONTAINS %@", "오늘 1회")
        ).firstMatch
        guard waitFor(todayValue, "widget today summary after timeline refresh", timeout: 15) else {
            attachTree("widget-summary-stale-after-completion", from: updatedWidget)
            return
        }
        XCTAssertTrue((todayValue.value as? String)?.contains("오늘 1회") == true,
                      "Widget today summary must report exactly one completion")
        let after = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        after.name = "springboard-widget-after-completion"
        after.lifetime = .keepAlways
        add(after)
        attachTree("springboard-widget-after-completion-tree", from: updatedWidget)

        // Require both installed sizes to show the saved event before deleting
        // it, so a stale initial zero cannot satisfy the deletion assertion.
        let installed = (0..<widgetIcons.count).map { widgetIcons.element(boundBy: $0) }
            .filter { $0.frame.width > 150 && $0.frame.height > 150 }
        XCTAssertTrue(installed.contains { $0.frame.width <= $0.frame.height * 1.5 }, "Small widget required")
        XCTAssertTrue(installed.contains { $0.frame.width > $0.frame.height * 1.5 }, "Medium widget required")
        for (index, icon) in installed.enumerated() {
            let one = icon.descendants(matching: .any).matching(
                NSPredicate(format: "value CONTAINS %@", "오늘 1회")
            ).firstMatch
            guard waitFor(one, "widget \(index) before deletion", timeout: 15) else { return }
        }

        relaunched.activate()
        guard waitFor(relaunched.tabBars.buttons["설정"], "settings tab") else { return }
        relaunched.tabBars.buttons["설정"].tap()
        let management = relaunched.buttons["데이터 관리"]
        for _ in 0..<8 where !management.isHittable { relaunched.swipeUp() }
        guard waitFor(management, "data management") else { return }
        management.tap()
        let deleteAll = relaunched.buttons["모든 기록 삭제"]
        for _ in 0..<8 where !deleteAll.isHittable { relaunched.swipeUp() }
        guard waitFor(deleteAll, "delete isolated fixture records") else { return }
        deleteAll.tap()
        let confirm = relaunched.buttons["삭제"]
        guard waitFor(confirm, "confirm fixture deletion") else { return }
        confirm.tap()
        guard waitFor(relaunched.staticTexts["모든 기록을 삭제했어요."], "deletion saved") else { return }
        relaunched.buttons["data-management-close"].tap()
        relaunched.tabBars.buttons["기록"].tap()
        guard waitFor(relaunched.staticTexts["아직 기록이 없어요. 오늘의 작은 선택을 남겨 보세요."], "empty history") else { return }

        XCUIDevice.shared.press(.home)
        springboard.activate()
        for (index, icon) in installed.enumerated() {
            let zero = icon.descendants(matching: .any).matching(
                NSPredicate(format: "value CONTAINS %@", "오늘 0회")
            ).firstMatch
            guard waitFor(zero, "widget \(index) after deletion", timeout: 15) else {
                attachTree("widget-stale-after-deletion-\(index)", from: icon)
                return
            }
            attachTree("widget-after-deletion-\(index)", from: icon)
        }
        let deleted = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        deleted.name = "small-medium-widgets-after-deletion"
        deleted.lifetime = .keepAlways
        add(deleted)
    }

    /// Re-arms one already-onboarded fixture for a true widget cold launch.
    /// The fixture identity is checked before any ritual gesture, and no
    /// Home Screen widget or fixture record is removed by this test.
    func testColdWidgetFixtureCompletesOnceAndUpdatesBothInstalledSizes() {
        for medium in [false, true] {
            runColdWidgetFixtureCompletion(medium: medium)
        }
    }

    private func runColdWidgetFixtureCompletion(medium: Bool) {
        continueAfterFailure = false
        let fixtureID = UUID()
        addFixtureAttachment(fixtureID, name: "cold-widget-fixture-id-\(medium)")

        let onboarding = launchFixture(fixtureID: fixtureID)
        completeOnboardingAtStrengthFive(onboarding)
        onboarding.terminate()
        XCTAssertTrue(onboarding.wait(for: .notRunning, timeout: 5))

        let armed = launchFixture(fixtureID: fixtureID, armCold: true)
        guard waitFor(armed.tabBars.buttons["기록"], "cold fixture history", timeout: 10) else { return }
        let today = armed.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "오늘 기록")
        ).firstMatch
        guard waitFor(today, "cold fixture baseline history") else { return }
        XCTAssertEqual(today.value as? String, "0회")
        armed.terminate()
        XCTAssertTrue(armed.wait(for: .notRunning, timeout: 5))

        XCUIDevice.shared.press(.home)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        springboard.activate()
        guard let widget = findInstalledWidget(in: springboard, medium: medium) else {
            attachTree("cold-widget-missing", from: springboard)
            XCTFail("No existing Maeumjaro widget was found on the Home Screen")
            return
        }
        XCTAssertEqual(armed.state, .notRunning)
        attachTree("cold-widget-before-start", from: widget)
        tapWidgetStart(widget)
        XCTAssertTrue(armed.wait(for: .runningForeground, timeout: 10))
        guard waitFor(armed.otherElements["ritual-canvas"], "cold fixture ritual") else { return }

        let identity = armed.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == %@", "qa-fixture-identity")
        ).firstMatch
        guard waitFor(identity, "cold fixture identity marker") else { return }
        // The marker's accessible label is the UUID itself. Keep this guard
        // before the unlock gesture so a production fallback cannot record.
        guard identity.label == fixtureID.uuidString else {
            XCTFail("Cold widget launch fixture identity mismatch: \(identity.label)")
            return
        }

        let canvas = armed.otherElements["ritual-canvas"]
        let left = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.22, dy: 0.5))
        let right = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.78, dy: 0.5))
        left.press(forDuration: 0.05, thenDragTo: right,
                   withVelocity: XCUIGestureVelocity.default, thenHoldForDuration: 0)
        canvas.press(forDuration: 0.45)
        let pauseHint = armed.staticTexts["ritual-hint"]
        guard waitFor(pauseHint, "cold fixture pause hint", timeout: 3) else { return }
        let pauseText = [pauseHint.label, pauseHint.value as? String]
            .compactMap { $0 }.joined(separator: " ")
        XCTAssertTrue(pauseText.contains("일시정지") || pauseText.contains("이어서"),
                      "RitualView must expose the paused state")
        let paused = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        paused.name = "cold-widget-paused"
        paused.lifetime = .keepAlways
        add(paused)
        canvas.press(forDuration: 3.4)
        guard waitFor(armed.staticTexts["의식 완료"], "cold fixture completion", timeout: 10) else { return }
        armed.buttons["기록 보기"].tap()
        guard waitFor(today, "cold fixture completed history") else { return }
        XCTAssertEqual(today.value as? String, "1회")
        let intensitySum = armed.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "오늘 강도 합")
        ).firstMatch
        guard waitFor(intensitySum, "cold fixture intensity sum") else { return }
        XCTAssertEqual(intensitySum.value as? String, "5")

        XCUIDevice.shared.press(.home)
        XCTAssertTrue(armed.wait(for: .runningBackground, timeout: 5))
        springboard.activate()
        for summaryMedium in [false, true] {
            guard let summaryWidget = findInstalledWidget(in: springboard, medium: summaryMedium) else {
                XCTFail("Both installed widget sizes are required after cold completion")
                return
            }
            let one = summaryWidget.descendants(matching: .any).matching(
                NSPredicate(format: "value CONTAINS %@", "오늘 1회")
            ).firstMatch
            guard waitFor(one, "cold source \(medium) summary \(summaryMedium)", timeout: 15) else { return }
            attachTree("cold-widget-source-\(medium)-summary-\(summaryMedium)", from: summaryWidget)
        }
        let after = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        after.name = "cold-widget-after-completion-\(medium)"
        after.lifetime = .keepAlways
        add(after)
    }
}
