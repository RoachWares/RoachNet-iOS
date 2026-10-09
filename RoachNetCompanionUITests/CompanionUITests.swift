import XCTest

/// UI tests for RoachNet iOS. They run the app in demo mode (no desktop needed) and
/// attach a screenshot of every screen so design changes can be reviewed in the
/// test report. Live pairing against a real runtime is covered by RoachNet's
/// `npm run smoke:ios-simulator-pairing`.
@MainActor
final class CompanionUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchEnvironment["ROACHNET_DEMO_MODE"] = "1"
        app.launch()
    }

    func testEveryTabOpensAndIsCaptured() throws {
        XCTAssertTrue(app.descendants(matching: .any)["screen.home"].firstMatch.waitForExistence(timeout: 15),
                      "Home should be the first screen")
        snapshot("01-home")

        for (id, name) in [("roachclaw", "02-roachclaw"), ("apps", "03-apps"), ("vault", "04-vault"), ("runtime", "05-runtime"), ("home", "06-home-again")] {
            let tab = app.buttons["tab.\(id)"]
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "Missing tab \(id)")
            tab.tap()
            XCTAssertTrue(tab.isSelected || tab.waitForSelection(), "Tab \(id) should be selected")
            sleep(1)
            snapshot(name)
        }
    }

    func testOrgApprovalCanBeApprovedFromHome() throws {
        let openOrg = app.buttons["home.openOrg"]
        XCTAssertTrue(openOrg.waitForExistence(timeout: 15))
        openOrg.tap()

        let approve = app.buttons["org.approve.apr_demo_1"]
        XCTAssertTrue(approve.waitForExistence(timeout: 10), "Demo approval should be listed")
        snapshot("07-org")
        approve.tap()

        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: approve)
        wait(for: [gone], timeout: 10)
        XCTAssertTrue(app.buttons["org.approve.apr_demo_2"].exists, "The other approval stays")
        snapshot("08-org-after-approve")
        app.buttons["org.done"].tap()
    }

    /// The RoachClaw composer must sit above the floating tab bar and take typing.
    func testChatComposerSitsAboveTheTabBar() throws {
        let tab = app.buttons["tab.roachclaw"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        sleep(1)

        let composer = app.textFields["chat.composer"].firstMatch
        XCTAssertTrue(composer.waitForExistence(timeout: 10), "Composer missing")
        let tabBar = app.buttons["tab.home"].firstMatch
        print("composer frame \(composer.frame), tab bar button frame \(tabBar.frame), window \(app.windows.firstMatch.frame)")
        XCTAssertLessThanOrEqual(composer.frame.maxY, tabBar.frame.minY, "Composer is hidden behind the tab bar")
        XCTAssertTrue(composer.isHittable, "Composer can't be tapped")
        composer.tap()
        composer.typeText("Check the water filter")
        XCTAssertTrue(app.buttons["chat.send"].firstMatch.isHittable, "Send can't be tapped with the keyboard up")
        snapshot("10-roachclaw-typing")
    }

    func testConnectionSheetOffersRoachTailPairing() throws {
        let connection = app.buttons["home.connection"]
        XCTAssertTrue(connection.waitForExistence(timeout: 15))
        connection.tap()
        XCTAssertTrue(app.buttons["Pair with RoachTail"].firstMatch.waitForExistence(timeout: 10))
        snapshot("09-connection")
    }

    private func snapshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private extension XCUIElement {
    func waitForSelection(timeout: TimeInterval = 3) -> Bool {
        let predicate = NSPredicate(format: "isSelected == true")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter().wait(for: [expectation], timeout: timeout) == .completed
    }
}
