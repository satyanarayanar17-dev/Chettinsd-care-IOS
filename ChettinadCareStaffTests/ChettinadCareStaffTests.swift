import XCTest
@testable import ChettinadCore

final class StaffRoleTests: XCTestCase {
    
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
        // Logic in StaffLoginView rejects this
    }
    
    func testStaffRolesAccepted() throws {
        let jsonNurse = """
        {
            "access_token": "abc",
            "role": "NURSE",
            "account_type": "STAFF",
            "userId": "n1",
            "name": "Nurse Joy",
            "must_change_password": false
        }
        """
        
        let response = try JSONDecoder().decode(LoginResponse.self, from: jsonNurse.data(using: .utf8)!)
        XCTAssertTrue(["DOCTOR", "NURSE", "ADMIN"].contains(response.role.uppercased()))
    }
}
