import XCTest

/// Measures cold app-launch duration for isolated empty fixtures.
/// The metric reports Simulator launch timing; it is not a device FPS measurement.
@MainActor
final class LaunchPerformanceTests: XCTestCase {
    private let bundleID = "com.yeoreum.maeumjaro"

    func testEmptyFixtureLaunchPerformance() {
        let options = XCTMeasureOptions()
        options.iterationCount = 3

        measure(metrics: [XCTApplicationLaunchMetric()], options: options) {
            let fixtureID = UUID()
            let fixtureAttachment = XCTAttachment(string: fixtureID.uuidString)
            fixtureAttachment.name = "launch-performance-fixture-id"
            fixtureAttachment.lifetime = .keepAlways
            add(fixtureAttachment)

            let app = XCUIApplication(bundleIdentifier: bundleID)
            app.launchArguments += [
                "-MaeumjaroFixtureID", fixtureID.uuidString,
                "-MaeumjaroFixture", "empty"
            ]
            app.launch()
            defer { app.terminate() }

            XCTAssertTrue(
                app.buttons["onboarding-next"].waitForExistence(timeout: 8),
                "Empty fixture launch must expose onboarding-next"
            )
        }
    }
}
