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
        signOut.tap()

        XCTAssertTrue(app.descendants(matching: .any)["login.root"].waitForExistence(timeout: 10))
    }
}
