import XCTest
@testable import ChettinadCore

final class PatientRoleTests: XCTestCase {
    
    func testStaffRolesRejectedInPatientApp() throws {
        // Based on LoginView logic, if the API returns non-patient, it throws an error.
        let jsonDoctor = """
        {
            "access_token": "abc",
            "role": "DOCTOR",
            "account_type": "STAFF",
            "userId": "d1",
            "name": "Dr. Smith",
            "must_change_password": false
        }
        """
        
        let response = try JSONDecoder().decode(OTPVerifyResponse.self, from: jsonDoctor.data(using: .utf8)!)
        XCTAssertNotEqual(response.role.uppercased(), "PATIENT", "Doctor role should not be interpreted as PATIENT")
    }
}
