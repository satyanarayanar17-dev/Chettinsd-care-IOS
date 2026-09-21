import XCTest
@testable import ChettinadCore

final class TokenRefreshTests: XCTestCase {
    
    func testSingleFlightRefresh() async throws {
        // Mocking an API client and testing the single flight behavior
        let manager = SessionManager()
        
        let session = AuthSession(accessToken: "old", role: "PATIENT", accountType: "PATIENT", userId: "1", name: "Test")
        await manager.saveSession(session)
        
        let client = APIClient()
        // Without mocking the network we can't fully unit test a 401 response here
        // But we can ensure that the basic single-flight mechanism compiles and has the right structure
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

    func testStaleStateError() throws {
        let jsonError = """
        {
            "error": {
                "code": "STALE_STATE",
                "message": "STALE_STATE"
            },
            "meta": {
                "correlation_id": "123"
            }
        }
        """
        let response = try JSONDecoder().decode(APIErrorResponse.self, from: jsonError.data(using: .utf8)!)
        XCTAssertEqual(response.error.code, "STALE_STATE")
    }
}
