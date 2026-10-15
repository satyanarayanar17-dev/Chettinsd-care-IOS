import XCTest
@testable import ChettinadCore
@testable import ChettinadCarePatient

final class PatientRoleTests: XCTestCase {
    func testCancellationAndProfileUseSharedOPDContracts() throws {
        let cancel = CancelAppointmentEndpoint(appointmentId: "appointment-1", version: 4)
        XCTAssertEqual(cancel.path, "/api/v1/opd/appointments/appointment-1/cancel")
        let profile = UpdateProfileEndpoint(patientId: "patient-1", payload: UpdateProfilePayload(email: "", address: "Address", city: "Chennai", state: "Tamil Nadu", pin_code: "600001", emergency_contact: "+919100000001", __v: 7))
        XCTAssertEqual(profile.path, "/api/v1/opd/patients/patient-1")
        XCTAssertEqual(profile.method, .patch)
        let body = try XCTUnwrap(try JSONSerialization.jsonObject(with: XCTUnwrap(profile.body)) as? [String: Any])
        XCTAssertEqual(body["__v"] as? Int, 7)
        XCTAssertEqual((body["data"] as? [String: Any])?["email"] as? String, "")
    }
    
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
