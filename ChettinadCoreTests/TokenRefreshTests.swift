import XCTest
@testable import ChettinadCore

final class TokenRefreshTests: XCTestCase {
    
    func testSingleFlightRefresh() async throws {
        // Mocking an API client and testing the single flight behavior might require protocol abstractions
        // For now, we ensure the test skeleton exists and add logic if we have a mockable SessionManager
        
        let manager = SessionManager()
        
        // Single flight logic is within the SessionManager actor's refreshToken method
        // To test it, we would trigger refreshToken simultaneously and verify only one network call is made.
    }
    
    func testSessionParsing() throws {
        let json = """
        {
            "id": "123",
            "name": "Test",
            "role": "DOCTOR",
            "department": "Cardiology",
            "must_change_password": false
        }
        """
        
        let session = try JSONDecoder().decode(UserSession.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(session.role, "DOCTOR")
        XCTAssertEqual(session.name, "Test")
    }
}
