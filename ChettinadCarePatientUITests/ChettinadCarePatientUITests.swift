import XCTest

@MainActor
final class ChettinadCarePatientUITests: XCTestCase {
    func testDemoPatientChallengeLoginAndRecordsOnThePhysicalDevice() async throws {
        let url=URL(string:"https://chettinad-care-api.onrender.com/api/v1/auth/opd/config")!
        let (data,_)=try await URLSession.shared.data(from:url)
        let config=try JSONSerialization.jsonObject(with:data) as? [String:Any]
        guard config?["demo_otp"] as? Bool == true else { throw XCTSkip("Physical smoke test is restricted to the synthetic demo") }
        let app=XCUIApplication();app.launchArguments=["-interface-language","en"];app.launch()
        if app.tabBars.buttons["Profile"].waitForExistence(timeout:10) { app.tabBars.buttons["Profile"].tap();app.buttons["Sign Out"].firstMatch.tap() }
        let phone=app.textFields["patient.phone"];XCTAssertTrue(phone.waitForExistence(timeout:30));phone.tap();phone.typeText("9000000001")
        app.buttons["patient.login.continue"].tap()
        let demo=app.staticTexts["patient.demo.code"];XCTAssertTrue(demo.waitForExistence(timeout:60))
        let code=String(demo.label.suffix(6));guard code.count==6&&code.allSatisfy(\.isNumber) else { XCTFail("Demo challenge unavailable");return }
        let field=app.textFields["patient.otp"];field.tap();field.typeText(code);app.swipeUp();app.buttons["patient.login.continue"].tap()
        XCTAssertTrue(app.tabBars.buttons["Records"].waitForExistence(timeout:60));app.tabBars.buttons["Records"].tap()
        XCTAssertTrue(app.staticTexts["Ananya Demo"].firstMatch.waitForExistence(timeout:30))
        let proof=XCTAttachment(screenshot:app.screenshot());proof.name="Physical patient records";proof.lifetime = .keepAlways;add(proof)
    }
}
