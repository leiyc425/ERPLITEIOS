import XCTest

final class AppFlowUITests: XCTestCase {
    func testMockLoginAndSignOut() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-session"]
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["login.root"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.descendants(matching: .any)["mock-data-banner"].exists)

        let username = app.textFields["login.username"]
        XCTAssertTrue(username.waitForExistence(timeout: 5))
        username.tap()
        username.typeText("ada")

        let password = app.secureTextFields["login.password"]
        XCTAssertTrue(password.waitForExistence(timeout: 5))
        password.tap()
        password.typeText("secret")

        let submit = app.buttons["login.submit"]
        if !submit.isHittable {
            app.swipeUp()
        }
        submit.tap()

        let signOut = app.buttons["dashboard.signOut"]
        XCTAssertTrue(signOut.waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["mock-data-banner"].exists)

        let inventory = app.descendants(matching: .any)["dashboard.inventory"]
        if !inventory.isHittable {
            app.swipeUp()
        }
        inventory.tap()
        XCTAssertTrue(app.staticTexts["Sample physical unit"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["inventory.list"].exists)

        app.tabBars.buttons["Dashboard"].tap()
        XCTAssertTrue(signOut.waitForExistence(timeout: 5))
        signOut.tap()

        XCTAssertTrue(app.descendants(matching: .any)["login.root"].waitForExistence(timeout: 10))
    }

    func testManualScanMatchChoiceAndDiscard() {
        let app = XCUIApplication()
        app.launchArguments = ["--reset-session"]
        app.launch()

        let username = app.textFields["login.username"]
        XCTAssertTrue(username.waitForExistence(timeout: 20))
        username.tap()
        username.typeText("ada")
        let password = app.secureTextFields["login.password"]
        password.tap()
        password.typeText("secret")
        let submit = app.buttons["login.submit"]
        if !submit.isHittable {
            app.swipeUp()
        }
        submit.tap()

        let signOut = app.buttons["dashboard.signOut"]
        XCTAssertTrue(signOut.waitForExistence(timeout: 10))
        let scan = app.buttons["dashboard.scan"]
        XCTAssertTrue(scan.waitForExistence(timeout: 5))
        scan.tap()

        let manual = app.descendants(matching: .any)["scan.manual"]
        XCTAssertTrue(manual.waitForExistence(timeout: 5))
        replace(manual, with: "0001", in: app)
        app.buttons["scan.lookup"].tap()
        let matchTitle = app.descendants(matching: .any)["scan.matchTitle"]
        XCTAssertTrue(matchTitle.waitForExistence(timeout: 5))
        XCTAssertEqual(matchTitle.label, "Sample physical unit")
        XCTAssertTrue(app.staticTexts["Mock sample. This was not loaded from ERP Lite."].exists)

        app.buttons["scan.again"].tap()
        XCTAssertTrue(manual.waitForExistence(timeout: 5))
        replace(manual, with: "SHARED-CODE", in: app)
        app.buttons["scan.lookup"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["scan.choice.sku-2"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["scan.choice.asset-2"].exists)
        app.descendants(matching: .any)["scan.choice.asset-2"].tap()
        XCTAssertEqual(app.descendants(matching: .any)["scan.matchTitle"].label, "Shared code asset")

        app.buttons["scan.again"].tap()
        XCTAssertTrue(manual.waitForExistence(timeout: 5))
        replace(manual, with: "UNKNOWN-99", in: app)
        app.buttons["scan.lookup"].tap()
        let miss = app.staticTexts["scan.none"]
        XCTAssertTrue(miss.waitForExistence(timeout: 5))
        XCTAssertTrue(miss.label.contains("does not prove"))
        XCTAssertFalse(miss.label.contains("does not exist"))
        app.buttons["scan.startDraft"].tap()
        app.buttons["scan.type.sku"].tap()

        let name = app.descendants(matching: .any)["scan.name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Unknown sample")
        app.buttons["scan.review"].tap()
        XCTAssertTrue(app.staticTexts["scan.reviewNote"].waitForExistence(timeout: 5))
        app.buttons["scan.discard"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["scan.manual"].waitForExistence(timeout: 5))
        app.buttons["scan.close"].tap()
        XCTAssertTrue(app.buttons["dashboard.signOut"].waitForExistence(timeout: 5))
    }

    private func replace(_ field: XCUIElement, with text: String, in app: XCUIApplication) {
        field.tap()
        let existing = (field.value as? String) ?? ""
        if existing != "Code" && !existing.isEmpty {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: existing.count))
        }
        field.typeText(text)
        if !app.buttons["scan.lookup"].isHittable {
            app.swipeUp()
        }
    }
}
