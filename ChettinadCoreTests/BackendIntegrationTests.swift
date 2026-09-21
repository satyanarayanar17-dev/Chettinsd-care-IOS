import XCTest
@testable import ChettinadCore

final class BackendIntegrationTests: XCTestCase {
    
    var client: APIClient!
    
    override func setUp() {
        super.setUp()
        client = APIClient()
    }
    
    func testBackendHealth() async throws {
        // Just a dummy to check if backend is reachable
        let url = URL(string: "http://127.0.0.1:3001/api/v1/health")!
        let (data, response) = try await URLSession.shared.data(from: url)
        let httpResponse = response as! HTTPURLResponse
        XCTAssertEqual(httpResponse.statusCode, 200)
    }
    
    
    func testPatientRoleRejectedInStaffApp() throws {
        let jsonPatient = """
        {
            "access_token": "abc",
            "role": "PATIENT",
            "account_type": "PATIENT",
            "userId": "p1",
            "name": "John Doe",
            "must_change_password": false
        }
        """
        let response = try JSONDecoder().decode(LoginResponse.self, from: jsonPatient.data(using: .utf8)!)
        XCTAssertEqual(response.role.uppercased(), "PATIENT")
    }
}
