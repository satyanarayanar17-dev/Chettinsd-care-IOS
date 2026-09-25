import XCTest

@MainActor
final class ChettinadCareStaffUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOTPLogin() throws {
        let app = XCUIApplication()
        app.launchEnvironment = ["CC_API_BASE_URL": "http://127.0.0.1:3011"]
        app.launch()

        // Wait for app to launch
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))

        // Take initial screenshot
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
