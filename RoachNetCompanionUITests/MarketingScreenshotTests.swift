import XCTest

/// Captures clean, paired-looking screens for roachnet.org and release notes.
/// Runs on demo data with `ROACHNET_SCREENSHOT_MODE=1` (no desktop, no preview banner).
/// Export with `xcrun xcresulttool export attachments`; names start with `shot-`.
@MainActor
final class MarketingScreenshotTests: XCTestCase {
    func testCaptureEveryScreen() throws {
        let app = XCUIApplication()
        app.launchEnvironment["ROACHNET_SCREENSHOT_MODE"] = "1"
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["screen.home"].firstMatch.waitForExistence(timeout: 15))
        sleep(2)
        capture(app, "shot-home")

        for (id, name) in [("roachclaw", "shot-roachclaw"), ("apps", "shot-apps"), ("vault", "shot-vault"), ("runtime", "shot-runtime")] {
            let tab = app.buttons["tab.\(id)"]
            XCTAssertTrue(tab.waitForExistence(timeout: 5))
            tab.tap()
            sleep(2)
            capture(app, name)
        }

        app.buttons["tab.home"].tap()
        let openOrg = app.buttons["home.openOrg"]
        XCTAssertTrue(openOrg.waitForExistence(timeout: 10))
        openOrg.tap()
        XCTAssertTrue(app.buttons["org.done"].waitForExistence(timeout: 10))
        sleep(2)
        capture(app, "shot-org")
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
