import XCTest

/// Audits the real app shell in both device appearances without writing a
/// completion record. Every run uses a fresh QA fixture namespace.
@MainActor
final class AppearanceAccessibilityTests: XCTestCase {
    private let bundleID = "com.yeoreum.maeumjaro"

    private struct ContrastCandidate {
        let element: XCUIElement
        let type: XCUIElement.ElementType
        let identifier: String
        let label: String
        let originalFrame: CGRect
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testLightAndDarkShellAppearanceAccessibility() throws {
        try auditAppearances(["light", "dark"])
    }

    func testLightShellAppearanceAccessibility() throws {
        try auditAppearances(["light"])
    }

    func testDarkAppearanceReachesUIKitAndSwiftUI() {
        let device = XCUIDevice.shared
        let original = device.appearance
        let app = XCUIApplication(bundleIdentifier: bundleID)
        defer { app.terminate(); device.appearance = original }
        device.appearance = .dark
        app.launchArguments = ["-MaeumjaroFixtureID", UUID().uuidString, "-MaeumjaroFixture", "free-boundary", "-MaeumjaroAuditAppearance", "-MaeumjaroAuditUIKit"]
        app.launch()
        let native = app.staticTexts["qa-uikit-appearance"]
        guard require(native, in: app, name: "dark-native-traits") else { return }
        let swiftUI = app.staticTexts["qa-appearance-state"]
        let predicate = NSPredicate(format: "value == %@", "dark|standard|quietIvory")
        let outcome = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: predicate, object: swiftUI)], timeout: 8)
        let traits = XCTAttachment(string: "device=\(device.appearance.rawValue);native=\(native.value ?? "missing");swiftUI=\(swiftUI.value ?? "missing")")
        traits.name = "effective-dark-trait-chain"
        traits.lifetime = .keepAlways
        add(traits)
        captureSurface("effective-dark-trait-chain", from: app)
        XCTAssertEqual(outcome, .completed)
        XCTAssertEqual(native.value as? String, "view=dark;window=dark;scene=dark")
    }

    private func auditAppearances(_ appearances: [String]) throws {
        let device = XCUIDevice.shared
        let originalAppearance = device.appearance
        let fixtureID = UUID()

        let fixture = XCTAttachment(string: fixtureID.uuidString)
        fixture.name = "appearance-accessibility-fixture-id"
        fixture.lifetime = .keepAlways
        add(fixture)

        defer {
            device.appearance = originalAppearance
        }

        for appearanceName in appearances {
            device.appearance = appearanceName == "light" ? .light : .dark

            let app = XCUIApplication(bundleIdentifier: bundleID)
            app.launchArguments = [
                "-MaeumjaroFixtureID", fixtureID.uuidString,
                "-MaeumjaroFixture", "free-boundary",
                "-MaeumjaroAuditAppearance"
            ]
            app.launch()
            device.appearance = appearanceName == "light" ? .light : .dark
            XCTAssertEqual(device.appearance, appearanceName == "light" ? .light : .dark)

            guard require(app.tabBars.buttons["기록"], in: app, name: "\(appearanceName)-history-tab") else { return }
            let appearanceState = app.staticTexts["qa-appearance-state"]
            guard require(appearanceState, in: app, name: "\(appearanceName)-actual-appearance") else { return }
            let actualAppearance = NSPredicate(format: "value == %@", "\(appearanceName)|standard|quietIvory")
            let appearanceReadback = XCTNSPredicateExpectation(predicate: actualAppearance, object: appearanceState)
            guard XCTWaiter.wait(for: [appearanceReadback], timeout: 8) == .completed else {
                captureSurface("mismatched-\(appearanceName)-appearance", from: app)
                XCTFail("Requested \(appearanceName), app reports \(appearanceState.value ?? "missing")")
                app.terminate()
                return
            }
            let identity = app.descendants(matching: .any).matching(
                NSPredicate(format: "identifier == %@", "qa-fixture-identity")
            ).firstMatch
            // Explicit fixture launches intentionally hide the QA overlay; when
            // the current build exposes it, verify its label against the UUID.
            if identity.waitForExistence(timeout: 2) {
                XCTAssertEqual(identity.label, fixtureID.uuidString)
            }

            captureSurface("\(appearanceName)-history", from: app)
            try audit(app, name: "\(appearanceName)-history")

            app.tabBars.buttons["홈"].tap()
            app.buttons["settings-open"].tap()
            guard require(app.buttons["settings-intensity-1"], in: app, name: "\(appearanceName)-settings-content") else { return }
            captureSurface("\(appearanceName)-settings", from: app)
            try audit(app, name: "\(appearanceName)-settings")

            app.buttons["settings-close"].tap()
            app.tabBars.buttons["기록"].tap()
            let baselineToday = app.descendants(matching: .any).matching(
                NSPredicate(format: "label == %@", "오늘 기록")
            ).firstMatch
            guard require(baselineToday, in: app, name: "\(appearanceName)-today-record") else { return }
            let baselineValue = baselineToday.value as? String

            app.tabBars.buttons["홈"].tap()
            let start = app.buttons["ritual-start"]
            guard require(start, in: app, name: "\(appearanceName)-ritual-start") else { return }
            start.tap()
            let canvas = app.otherElements["ritual-canvas"]
            guard require(canvas, in: app, name: "\(appearanceName)-ritual-canvas") else { return }
            captureSurface("\(appearanceName)-ritual", from: app)
            try audit(app, name: "\(appearanceName)-ritual")

            let close = app.buttons["ritual-close"]
            guard require(close, in: app, name: "\(appearanceName)-ritual-close") else { return }
            close.tap()
            XCTAssertTrue(canvas.waitForNonExistence(timeout: 5), "Ritual must close safely")
            XCTAssertEqual(baselineToday.value as? String, baselineValue, "Closing a ritual must not create a record")
            app.terminate()
        }
    }

    @discardableResult
    private func require(_ element: XCUIElement, in app: XCUIApplication, name: String) -> Bool {
        guard element.waitForExistence(timeout: 8) else {
            captureSurface("missing-\(name)", from: app)
            XCTFail("Missing UI element: \(name)")
            return false
        }
        return true
    }

    private func captureSurface(_ name: String, from app: XCUIApplication) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = "\(name)-screenshot"
        screenshot.lifetime = .keepAlways
        add(screenshot)

        let tree = XCTAttachment(string: app.debugDescription)
        tree.name = "\(name)-tree"
        tree.lifetime = .keepAlways
        add(tree)
    }

    private func audit(_ app: XCUIApplication, name: String) throws {
        var deferredCandidates: [String: ContrastCandidate] = [:]
        let tabBar = app.tabBars.firstMatch
        let windowFrame = app.windows.firstMatch.frame
        let bottomEdge = tabBar.exists ? tabBar.frame.minY - 80 : windowFrame.maxY - 80

        // Keep collecting every issue so one failure does not hide later views.
        continueAfterFailure = true
        defer {
            continueAfterFailure = false
            restoreScrollToTop(in: app)
        }
        try app.performAccessibilityAudit(for: [.contrast, .hitRegion]) { issue in
            if issue.auditType.contains(.contrast), let element = issue.element {
                let frame = element.frame
                let partlyOutsideViewport = frame.minY < windowFrame.minY || frame.maxY > windowFrame.maxY
                let touchesBottomEdge = frame.maxY >= bottomEdge || partlyOutsideViewport
                if touchesBottomEdge {
                    let identifier = element.identifier
                    let label = element.label
                    let key = "\(element.elementType.rawValue)|\(identifier)|\(label)|\(frame.minX)|\(frame.minY)|\(frame.width)|\(frame.height)"
                    deferredCandidates[key] = ContrastCandidate(
                        element: element,
                        type: element.elementType,
                        identifier: identifier,
                        label: label,
                        originalFrame: frame
                    )
                    let detail = XCTAttachment(string: "\(issue)\n\(element.debugDescription)")
                    detail.name = "\(name)-edge-contrast-issue"
                    detail.lifetime = .keepAlways
                    self.add(detail)
                    return true
                }
            }

            let detail = XCTAttachment(string: "\(issue)\n\(issue.element?.debugDescription ?? "No element supplied")")
            detail.name = "\(name)-audit-issue"
            detail.lifetime = .keepAlways
            self.add(detail)
            XCTFail("\(name) accessibility issue: \(issue)")
            return false
        }

        for candidate in deferredCandidates.values.sorted(by: { candidate, other in
            if candidate.originalFrame.minY != other.originalFrame.minY {
                return candidate.originalFrame.minY < other.originalFrame.minY
            }
            if candidate.originalFrame.minX != other.originalFrame.minX {
                return candidate.originalFrame.minX < other.originalFrame.minX
            }
            return candidate.label < other.label
        }) {
            guard let target = center(candidate, in: app, tabBar: tabBar, windowFrame: windowFrame) else {
                captureSurface("\(name)-contrast-center-failed", from: app)
                XCTFail("\(name) contrast candidate could not be centered: \(candidate.label)")
                continue
            }

            captureSurface("\(name)-contrast-\(candidate.identifier.isEmpty ? candidate.label : candidate.identifier)", from: app)
            var targetIssue: XCUIAccessibilityAuditIssue?
            try app.performAccessibilityAudit(for: [.contrast]) { issue in
                guard issue.auditType.contains(.contrast), let issueElement = issue.element else {
                    return true
                }
                if self.matches(issueElement, candidate: candidate, near: target.frame) {
                    targetIssue = issue
                    let detail = XCTAttachment(string: "\(issue)\n\(issueElement.debugDescription)")
                    detail.name = "\(name)-targeted-contrast-issue"
                    detail.lifetime = .keepAlways
                    self.add(detail)
                    return false
                }
                // The targeted pass is intentionally scoped to this candidate.
                return true
            }
            if let targetIssue {
                XCTFail("\(name) targeted contrast issue: \(targetIssue)")
            }
        }
    }

    private func center(
        _ candidate: ContrastCandidate,
        in app: XCUIApplication,
        tabBar: XCUIElement,
        windowFrame: CGRect
    ) -> XCUIElement? {
        let upper = (tabBar.exists ? tabBar.frame.minY : windowFrame.maxY) - 120
        let lower = windowFrame.minY + 120
        let containers = app.scrollViews.allElementsBoundByIndex + app.tables.allElementsBoundByIndex + app.collectionViews.allElementsBoundByIndex

        for _ in 0..<6 {
            let target = candidate.element.exists ? candidate.element : matchingElement(candidate, in: app)
            guard let target else { return nil }
            let frame = target.frame
            if frame.minY >= lower && frame.maxY <= upper && frame.minY >= windowFrame.minY && frame.maxY <= windowFrame.maxY {
                return target
            }

            let container = containers.first(where: { $0.frame.contains(centerPoint(frame)) }) ?? containers.first
            guard let container else { return nil }
            let desiredMidY = (lower + upper) / 2
            let distance = max(-160, min(160, desiredMidY - frame.midY))
            let start = container.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)))
        }
        let target = candidate.element.exists ? candidate.element : matchingElement(candidate, in: app)
        guard let target else { return nil }
        let frame = target.frame
        return frame.minY >= lower && frame.maxY <= upper ? target : nil
    }

    private func matchingElement(_ candidate: ContrastCandidate, in app: XCUIApplication) -> XCUIElement? {
        let predicate: NSPredicate
        if candidate.identifier.isEmpty {
            predicate = NSPredicate(format: "label == %@", candidate.label)
        } else {
            predicate = NSPredicate(format: "identifier == %@ AND label == %@", candidate.identifier, candidate.label)
        }
        let matches = app.descendants(matching: candidate.type).matching(predicate).allElementsBoundByIndex
        guard matches.count == 1 else { return nil }
        return matches.first
    }

    private func matches(_ element: XCUIElement, candidate: ContrastCandidate, near frame: CGRect) -> Bool {
        element.elementType == candidate.type &&
            element.identifier == candidate.identifier &&
            element.label == candidate.label &&
            distance(centerPoint(element.frame), from: centerPoint(frame)) < 80
    }

    private func distance(_ lhs: CGPoint, from rhs: CGPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }

    private func centerPoint(_ frame: CGRect) -> CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }

    private func restoreScrollToTop(in app: XCUIApplication) {
        let containers = app.scrollViews.allElementsBoundByIndex + app.tables.allElementsBoundByIndex + app.collectionViews.allElementsBoundByIndex
        for container in containers {
            for _ in 0..<6 { container.swipeDown() }
        }
    }
}
