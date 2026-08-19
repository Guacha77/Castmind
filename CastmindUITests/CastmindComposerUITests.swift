import XCTest

final class CastmindComposerUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testChatComposerIsVisibleHittableAndOpensKeyboard() throws {
        app = launchApp(arguments: ["CASTMIND_UI_TEST"])

        let field = composerTextInput(prefix: "chat")
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue(field.isHittable)
        assertElementInsideScreen(field)
        XCTAssertTrue(app.buttons["chat.microphone"].exists)
        XCTAssertTrue(app.buttons["chat.microphone"].isHittable)
        XCTAssertTrue(app.buttons["chat.send"].exists)
        attachScreenshot(named: "Chat sin teclado")
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        attachScreenshot(named: "Chat con teclado abierto")

        field.typeText("hola")
        XCTAssertTrue(field.valueText.contains("hola"))
        XCTAssertTrue(app.buttons["chat.send"].isHittable)
    }

    func testRoomComposerIsVisibleHittableAndOpensKeyboard() throws {
        app = launchApp(arguments: ["CASTMIND_UI_TEST", "CASTMIND_UI_TEST_ROOM"])

        let roomRow = app.buttons["room.row"]
        XCTAssertTrue(roomRow.waitForExistence(timeout: 5))
        roomRow.tap()

        let field = composerTextInput(prefix: "room")
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue(field.isHittable)
        assertElementInsideScreen(field)
        XCTAssertTrue(app.buttons["room.microphone"].exists)
        XCTAssertTrue(app.buttons["room.microphone"].isHittable)
        XCTAssertTrue(app.buttons["room.send"].exists)
        attachScreenshot(named: "Room sin teclado")
        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 3))
        attachScreenshot(named: "Room con teclado abierto")

        field.typeText("hola")
        XCTAssertTrue(field.valueText.contains("hola"))
        XCTAssertTrue(app.buttons["room.send"].isHittable)
    }

    private func launchApp(arguments: [String]) -> XCUIApplication {
        let launched = XCUIApplication()
        launched.launchArguments = arguments
        launched.launch()
        return launched
    }

    private func composerTextInput(prefix: String) -> XCUIElement {
        let textField = app.textFields["\(prefix).textfield"]
        if textField.exists { return textField }
        let textView = app.textViews["\(prefix).textfield"]
        if textView.exists { return textView }
        return app.descendants(matching: .any)["\(prefix).textfield"]
    }

    private func assertElementInsideScreen(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let screenFrame = app.windows.firstMatch.frame
        let elementFrame = element.frame
        XCTAssertGreaterThan(elementFrame.height, 40, file: file, line: line)
        XCTAssertGreaterThanOrEqual(elementFrame.minY, screenFrame.minY, file: file, line: line)
        XCTAssertLessThanOrEqual(elementFrame.maxY, screenFrame.maxY, file: file, line: line)
    }

    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

private extension XCUIElement {
    var valueText: String {
        (value as? String) ?? ""
    }
}
