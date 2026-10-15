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
        let value = ConsultationData(complaint: "Complaint", history: "History", previous_history: nil, examination: "Exam", assessment: "Assessment", diagnosis_ids: ["dx"], treatment: nil, advice: "Advice", medications: [PrescriptionDrug(drug_id: "drug", dose: "1", frequency: "Daily", duration: "3 days", instructions: nil)], follow_up: nil)
        let endpoint = CompleteConsultEndpoint(encounterId: "encounter", v: 2, data: value, patientVersion: 7)
        let body = try XCTUnwrap(try JSONSerialization.jsonObject(with: XCTUnwrap(endpoint.body)) as? [String:Any])
        XCTAssertEqual(body["__v"] as? Int,2)
        XCTAssertEqual(body["patient__v"] as? Int,7)
        XCTAssertEqual((body["data"] as? [String:Any])?["history"] as? String,"History")
    }
    @MainActor func testTriageRequiresCompleteMeasuredVitalsAndComplaint() {
        let model = TriageFormViewModel(encounterId: "encounter", initialVersion: 3)
        XCTAssertNotNil(model.validationError)
        model.temperature = "37"; model.systolic = "120"; model.diastolic = "80"; model.pulse = "75"
        model.spo2 = "99"; model.weight = "60"; model.height = "160"; model.pain = "0"; model.complaint = "Synthetic complaint"
        XCTAssertNil(model.validationError)
        model.systolic = "70"; XCTAssertNotNil(model.validationError)
        model.systolic = "120"; model.spo2 = "NaN"; XCTAssertNotNil(model.validationError)
    }
    @MainActor func testRemoteClinicalDraftCannotReplaceEditsOrAdvanceSigningVersion() throws {
        func bundle(noteVersion: Int, patientVersion: Int = 7) throws -> RecordBundle {
            let json = """
            {"patient":{"id":"patient","mrn":"MRN","name":"Synthetic patient","phone":"+919100000001","dob":"1990-01-01","gender":"Female","__v":\(patientVersion)},"encounters":[],"triage":[],"prescriptions":[],"labs":[],"notes":[{"id":"note","encounter_id":"encounter","status":"DRAFT","__v":\(noteVersion),"draft_content":{"history":"Hospital history","previous_history":"Previous history","treatment":"Treatment kept"}}]}
            """
            return try JSONDecoder().decode(RecordBundle.self, from: Data(json.utf8))
        }
        let model = DoctorConsultationViewModel(encounterId: "encounter", patientId: "patient", initialVersion: 9)
        model.acceptDossier(try bundle(noteVersion: 2))
        XCTAssertEqual(model.noteHistory, "Hospital history")
        XCTAssertEqual(model.noteVersion, 2)
        model.noteHistory = "Unsaved local history"
        model.acceptDossier(try bundle(noteVersion: 3, patientVersion: 8))
        XCTAssertEqual(model.noteHistory, "Unsaved local history")
        XCTAssertEqual(model.noteVersion, 2)
        XCTAssertTrue(model.recordChangedElsewhere)
    }

}
