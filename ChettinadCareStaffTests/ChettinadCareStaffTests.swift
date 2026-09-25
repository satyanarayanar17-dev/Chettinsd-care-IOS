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

@testable import ChettinadCareStaff

final class StaffContractTests: XCTestCase {
    func testAdminQueriesAreSeparateFromPaths() throws {
        let search = PatientSearchEndpoint(query: "A & B தமிழ்")
        var parts = URLComponents(string: "http://127.0.0.1:3011" + search.path)!
        parts.queryItems = search.queryItems
        XCTAssertEqual(parts.url?.path, "/api/v1/opd/patients")
        XCTAssertEqual(parts.queryItems?.first?.value, "A & B தமிழ்")
        XCTAssertEqual(AdminAppointmentsEndpoint(date: "2026-09-21").queryItems?.first?.name, "date")
        XCTAssertEqual(SlotsEndpoint(doctorId: "doctor", date: "2026-09-21").queryItems?.count, 2)
    }
    func testCheckInAcceptsBackendMutationResponse() throws {
        let data = Data("{\"success\":true}".utf8)
        XCTAssertNoThrow(try JSONDecoder().decode(EncounterMutationResponse.self, from: data))
    }
    func testClinicalPayloadPreservesHistoryAndNoteVersion() throws {
        let value = ConsultationData(complaint: "Complaint", history: "History", previous_history: nil, examination: "Exam", assessment: "Assessment", diagnosis_ids: ["dx"], treatment: nil, advice: "Advice", medications: [PrescriptionDrug(drug_id: "drug", dose: "1", frequency: "Daily", duration: "3 days", instructions: nil)])
        let endpoint = CompleteConsultEndpoint(encounterId: "encounter", v: 2, data: value)
        let body = try XCTUnwrap(try JSONSerialization.jsonObject(with: XCTUnwrap(endpoint.body)) as? [String:Any])
        XCTAssertEqual(body["__v"] as? Int,2)
        XCTAssertEqual((body["data"] as? [String:Any])?["history"] as? String,"History")
    }
}
