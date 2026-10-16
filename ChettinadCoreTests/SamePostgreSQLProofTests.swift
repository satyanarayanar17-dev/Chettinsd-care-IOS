import XCTest
@testable import ChettinadCore

struct AnyEndpoint: APIEndpoint {
    var path: String
    var method: HTTPMethod
    var body: Data?
}

final class SharedBackendProofTests: XCTestCase {
    func unwrap<T>(_ value: T?) throws -> T { try XCTUnwrap(value) }
    var base: String = ""
    override func setUpWithError() throws {
        #if CC_SHARED_FIXTURE
        base = "http://127.0.0.1:3005"
        #else
        guard let value = ProcessInfo.processInfo.environment["CC_INTEGRATION_BASE_URL"], value == "http://127.0.0.1:3011" else {
            throw XCTSkip("Requires disposable PostgreSQL fixture: tests/start-native.cjs on port 3011")
        }
        base = value
        #endif
    }
    func request(_ path: String, _ method: String = "GET", _ body: [String: Any]? = nil, _ token: String? = nil, status: Int = 200) async throws -> Any {
        var req = URLRequest(url: URL(string: base + path)!)
        req.httpMethod = method
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        if let body { req.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, response) = try await URLSession.shared.data(for: req)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, status, path + ": " + String(decoding: data, as: UTF8.self))
        return try JSONSerialization.jsonObject(with: data)
    }
    func login(_ id: String) async throws -> String {
        let result = try await request("/api/v1/auth/login/staff", "POST", ["username": id, "password": "ChettinadDemo2026!" ]) as? [String: Any]
        return try unwrap(result?["access_token"] as? String)
    }
    func queue(_ token: String) async throws -> [[String: Any]] {
        return try unwrap(try await request("/api/v1/opd/queue", "GET", nil, token) as? [[String: Any]])
    }
    func testSharedPatientNurseDoctorRecordsAndPermissions() async throws {
        let doctor = try await login("demo_doctor")
        let nurse = try await login("demo_nurse")
        let admin = try await login("demo_admin")
        let catalogue = try unwrap(try await request("/api/v1/opd/catalogues", "GET", nil, doctor) as? [String: Any])
        let diagnosis = try unwrap((catalogue["diagnoses"] as? [[String: Any]])?.first?["id"] as? String)
        let drug = try unwrap((catalogue["drugs"] as? [[String: Any]])?.first?["id"] as? String)
        // Finish the independent seeded consultation before handing off the nurse fixture.
        let active = try unwrap(try await queue(doctor).first { $0["status"] as? String == "CONSULTATION" })
        let activeId = try unwrap(active["encounter_id"] as? String)
        let activePatient = try unwrap(active["patient_id"] as? String)
        let activeRecord = try unwrap(try await request("/api/v1/opd/patients/\(activePatient)/record", "GET", nil, doctor) as? [String: Any])
        let noteVersion = (activeRecord["notes"] as? [[String: Any]])?.first { $0["encounter_id"] as? String == activeId }?["__v"] as? Int ?? 0
        let clinical: [String: Any] = ["history":"Synthetic validation history", "examination":"Synthetic examination", "assessment":"Synthetic assessment", "diagnosis_ids":[diagnosis], "advice":"Synthetic advice", "medications":[["drug_id":drug,"dose":"1 tablet","frequency":"Daily","duration":"3 days"]]]
        let activeProfile = try unwrap(activeRecord["patient"] as? [String: Any])
        _ = try await request("/api/v1/opd/encounters/\(activeId)/complete", "POST", ["data":clinical,"__v":noteVersion,"patient__v":try unwrap(activeProfile["__v"] as? Int)], doctor)
        let entry = try unwrap(try await queue(nurse).first { $0["patient_name"] as? String == "Ananya Raman (Demo)" })
        let encounter = try unwrap(entry["encounter_id"] as? String)
        let patient = try unwrap(entry["patient_id"] as? String)
        let version = try unwrap(entry["__v"] as? Int)
        _ = try await request("/api/v1/opd/encounters/\(encounter)/start-triage", "POST", ["__v":version], nurse)
        let updated = try unwrap(try await queue(nurse).first { $0["encounter_id"] as? String == encounter })
        let vitals: [String:Any] = ["temperature":36.8,"systolic":120,"diastolic":80,"pulse":74,"spo2":98,"weight":62,"height":164,"pain":2,"complaint":"Native handoff validation","notes":"Exact nurse handoff note","priority":0]
        _ = try await request("/api/v1/opd/encounters/\(encounter)/triage", "POST", ["data":vitals,"__v":try unwrap(updated["__v"] as? Int)], nurse)
        let handed = try unwrap(try await queue(doctor).first { $0["encounter_id"] as? String == encounter })
        XCTAssertEqual(handed["status"] as? String, "WAITING_DOCTOR")
        _ = try await request("/api/v1/opd/encounters/\(encounter)/start", "POST", ["__v":try unwrap(handed["__v"] as? Int)], doctor)
        let test = try unwrap((catalogue["tests"] as? [[String:Any]])?.first?["id"] as? String)
        _ = try await request("/api/v1/opd/encounters/\(encounter)/labs", "POST", ["test_id":test], doctor, status:201)
        let duplicate = try await request("/api/v1/opd/encounters/\(encounter)/labs", "POST", ["test_id":test], doctor, status:409) as? [String:Any]
        XCTAssertEqual((duplicate?["error"] as? [String:Any])?["code"] as? String,"TEST_ALREADY_ORDERED")
        _ = try await request("/api/v1/opd/encounters/\(encounter)/complete", "POST", ["data":clinical,"__v":0], nurse, status:403)
        _ = try await request("/api/v1/opd/encounters/\(encounter)/complete", "POST", ["data":clinical,"__v":0], admin, status:403)
        let reviewedRecord = try unwrap(try await request("/api/v1/opd/patients/\(patient)/record", "GET", nil, doctor) as? [String: Any])
        let reviewedPatient = try unwrap(reviewedRecord["patient"] as? [String: Any])
        _ = try await request("/api/v1/opd/encounters/\(encounter)/complete", "POST", ["data":clinical,"__v":0,"patient__v":try unwrap(reviewedPatient["__v"] as? Int)], doctor)
        let otp = try unwrap(try await request("/api/v1/auth/opd/otp/request", "POST", ["phone":"+919000000001"]) as? [String:Any])
        _ = try await request("/api/v1/auth/opd/otp/verify", "POST", ["phone":"+919000000001","code":"000000"], status:401)
        let authenticated = try unwrap(try await request("/api/v1/auth/opd/otp/verify", "POST", ["phone":"+919000000001","code":try unwrap(otp["development_code"] as? String),"challenge_id":try unwrap(otp["challenge_id"] as? String)]) as? [String:Any])
        let token = try unwrap(authenticated["access_token"] as? String)
        let record = try unwrap(try await request("/api/v1/opd/patients/\(patient)/record", "GET", nil, token) as? [String:Any])
        let decoded = try JSONDecoder().decode(RecordBundle.self, from: JSONSerialization.data(withJSONObject: record))
        XCTAssertEqual(decoded.patient.id, patient)
        XCTAssertFalse(decoded.prescriptions.isEmpty)
        let triage = try unwrap((record["triage"] as? [[String:Any]])?.first?["data"] as? [String:Any])
        XCTAssertEqual(triage["notes"] as? String,"Exact nurse handoff note")
        XCTAssertEqual(triage["pulse"] as? Int,74)
        let prescription = try unwrap((record["prescriptions"] as? [[String:Any]])?.first?["rx_content"] as? [String:Any])
        XCTAssertEqual((prescription["medications"] as? [[String:Any]])?.first?["drug_id"] as? String,drug)
        _ = try await request("/api/v1/opd/patients/\(activePatient)/record", "GET", nil, token, status:404)
        _ = try await request("/api/v1/opd/staff", "GET", nil, token, status:403)
    }
}
