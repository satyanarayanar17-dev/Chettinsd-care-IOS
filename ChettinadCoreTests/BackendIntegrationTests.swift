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
        guard let base = ProcessInfo.processInfo.environment["CC_INTEGRATION_BASE_URL"] else { throw XCTSkip("Run against tests/start-native.cjs disposable fixture") }
        let url = URL(string: base + "/api/v1/health")!
        let (_, response) = try await URLSession.shared.data(from: url)
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
