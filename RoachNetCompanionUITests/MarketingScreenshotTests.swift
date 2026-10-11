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
        openOrg.scrollAboveTabBar(in: app)
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

extension XCUIElement {
    /// The floating tab bar sits over the bottom of each scroll view, so a tap on
    /// a control behind it lands on a tab instead. Scroll until it clears the bar.
    func scrollAboveTabBar(in app: XCUIApplication) {
        let tab = app.buttons["tab.home"]
        guard tab.exists else { return }
        var swipes = 0
        while frame.maxY > tab.frame.minY - 8, swipes < 4 {
            app.swipeUp(velocity: .slow)
            swipes += 1
        }
    }
}
