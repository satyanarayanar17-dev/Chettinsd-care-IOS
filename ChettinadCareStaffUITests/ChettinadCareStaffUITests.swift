import XCTest

@MainActor
final class ChettinadCareStaffUITests: XCTestCase {
    func testDemoAdminLoginLoadsOverviewOnThePhysicalDevice() async throws {
        let url=URL(string:"https://chettinad-care-api.onrender.com/api/v1/auth/opd/config")!
        let (data,_)=try await URLSession.shared.data(from:url)
        let config=try JSONSerialization.jsonObject(with:data) as? [String:Any]
        guard config?["demo_otp"] as? Bool == true else { throw XCTSkip("Physical smoke test is restricted to the synthetic demo") }
        let app=XCUIApplication();app.launchArguments=["-interface-language","en"];app.launch()
        if app.tabBars.buttons["Profile"].waitForExistence(timeout:10) { app.tabBars.buttons["Profile"].tap();app.buttons["Sign Out"].firstMatch.tap() }
        let username=app.textFields["staff.username"];XCTAssertTrue(username.waitForExistence(timeout:30));username.tap();username.typeText("admin")
        let password=app.secureTextFields["staff.password"];password.tap();password.typeText("ChettinadDemo2026!")
        app.buttons["staff.login"].tap()
        XCTAssertTrue(app.staticTexts["Total Appointments"].waitForExistence(timeout:60))
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format:"label CONTAINS[c] %@","sqlite_error")).firstMatch.exists)
        let proof=XCTAttachment(screenshot:app.screenshot());proof.name="Physical staff overview";proof.lifetime = .keepAlways;add(proof)
    }
}
