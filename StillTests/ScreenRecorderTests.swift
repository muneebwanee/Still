import XCTest

@MainActor final class StillUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting-reset"]
        app.launch()
        return app
    }
    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<5 { if element.isHittable { break }; app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }
    private func enterApp(_ app: XCUIApplication) {
        let start = app.buttons["Let’s watch"]
        XCTAssertTrue(start.waitForExistence(timeout: 8))
        app.swipeUp()
        start.tap()
    }
    func testLegalLibraryIsAvailableBeforeOnboarding() {
        let app = launch()
        let library = app.buttons["Read privacy & legal pages offline"]
        XCTAssertTrue(library.waitForExistence(timeout: 8))
        app.swipeUp()
        library.tap()
        let eula = app.buttons.containing(.staticText, identifier: "Store End User License Agreement").firstMatch
        XCTAssertTrue(eula.waitForExistence(timeout: 5))
        eula.tap()
        XCTAssertTrue(app.staticTexts["In plain words"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Share this document"].exists)
    }
    func testQueueOnlyPreferenceSurvivesRelaunch() {
        let app = launch()
        enterApp(app)
        app.buttons["Settings"].tap()
        let queue = app.switches["Queue-only remotes"]
        reveal(queue, in: app)
        queue.tap()
        XCTAssertEqual(queue.value as? String, "1")
        app.terminate()
        app.launchArguments = []
        app.launch()
        app.buttons["Settings"].tap()
        reveal(app.switches["Queue-only remotes"], in: app)
        XCTAssertEqual(app.switches["Queue-only remotes"].value as? String, "1")
    }
    func testLocalWipeReturnsToWelcomeAndResetsPreferences() {
        let app = launch()
        enterApp(app)
        app.buttons["Settings"].tap()
        reveal(app.switches["Queue-only remotes"], in: app)
        app.switches["Queue-only remotes"].tap()
        let privacy = app.buttons["Privacy & data"]
        reveal(privacy, in: app)
        privacy.tap()
        let wipe = app.buttons["Wipe local data now"]
        if !wipe.isHittable { app.swipeUp() }
        wipe.tap()
        app.buttons["Stop & wipe local data"].tap()
        XCTAssertTrue(app.buttons["Let’s watch"].waitForExistence(timeout: 20))
        enterApp(app)
        app.buttons["Settings"].tap()
        reveal(app.switches["Queue-only remotes"], in: app)
        XCTAssertEqual(app.switches["Queue-only remotes"].value as? String, "0")
    }
}
