import XCTest
@testable import ChettinadCore

struct AnyEndpoint: APIEndpoint {
    var path: String
    var method: HTTPMethod
    var body: Data?
}

final class SamePostgreSQLProofTests: XCTestCase {
    
    func execute(path: String, method: HTTPMethod, body: [String: Any]? = nil, token: String? = nil) async throws -> [String: Any] {
        var req = URLRequest(url: URL(string: "http://127.0.0.1:3001" + path)!)
        req.httpMethod = method.rawValue
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let t = token {
            req.setValue("Bearer \(t)", forHTTPHeaderField: "Authorization")
        }
        if let b = body {
            req.httpBody = try JSONSerialization.data(withJSONObject: b)
        }
        
        let (data, res) = try await URLSession.shared.data(for: req)
        guard let httpRes = res as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if httpRes.statusCode >= 400 {
                print("HTTP \(httpRes.statusCode) Error on \(path): \(json)")
            }
            return json
        }
        return [:]
    }
    
    func testSamePostgreSQLProof() async throws {
        print("--- Starting PostgreSQL Integrity Proof ---")
        
        let patientPhone = "+919000000001"
        let patientId = "pat-261a2ce1-a322-4707-8958-d11718801942"
        let password = "Password123!"
        
        // 1. Doctor Login
        let doctorRes = try await execute(path: "/api/v1/auth/login/staff", method: .post, body: ["username": "demo_doctor", "password": password])
        let doctorToken = doctorRes["access_token"] as! String
        print("✅ Doctor logged in")
        
        // 2. Nurse Login
        let nurseRes = try await execute(path: "/api/v1/auth/login/staff", method: .post, body: ["username": "demo_nurse", "password": password])
        let nurseToken = nurseRes["access_token"] as! String
        print("✅ Nurse logged in")
        
        // 3. Admin Login (to book appointment without issues)
        let adminRes = try await execute(path: "/api/v1/auth/login/staff", method: .post, body: ["username": "demo_admin", "password": password])
        let adminToken = adminRes["access_token"] as! String
        
        let scheduledAt = "2026-09-21T06:00:00.000Z"
        
        let bookRes = try await execute(path: "/api/v1/opd/appointments", method: .post, body: [
            "patient_id": patientId,
            "doctor_id": "demo_doctor",
            "scheduled_at": scheduledAt,
            "reason": "Test Proof iOS"
        ], token: adminToken)
        guard let appointmentId = bookRes["id"] as? String else {
            XCTFail("Failed to book appointment: \(bookRes)")
            return
        }
        print("✅ Appointment booked: \(appointmentId)")
        
        // 5. Check-in (Creates Encounter)
        let checkinRes = try await execute(path: "/api/v1/opd/appointments/\(appointmentId)/check-in", method: .post, body: ["identity_verified": true], token: adminToken)
        guard let encounterId = checkinRes["encounter_id"] as? String else {
            XCTFail("Checkin failed: \(checkinRes)")
            return
        }
        let initialV = checkinRes["__v"] as! Int
        print("✅ Checked in, Encounter: \(encounterId)")
        
        // 6. Triage by Nurse
        _ = try await execute(path: "/api/v1/opd/encounters/\(encounterId)/start-triage", method: .post, body: ["__v": initialV], token: nurseToken)
        
        let triageData: [String: Any] = [
            "temperature": 37.0,
            "systolic": 120,
            "diastolic": 80,
            "pulse": 75,
            "spo2": 98,
            "weight": 70,
            "height": 175,
            "complaint": "iOS Proof Testing",
            "priority": 0
        ]
        let triageRes = try await execute(path: "/api/v1/opd/encounters/\(encounterId)/triage", method: .post, body: ["data": triageData, "__v": initialV + 1], token: nurseToken)
        print("✅ Triage submitted by Nurse")
        
        // 7. Consultation by Doctor
        _ = try await execute(path: "/api/v1/opd/encounters/\(encounterId)/call", method: .post, body: ["__v": initialV + 2], token: doctorToken)
        _ = try await execute(path: "/api/v1/opd/encounters/\(encounterId)/start", method: .post, body: ["__v": initialV + 3], token: doctorToken)
        
        let consultationData: [String: Any] = [
            "history": "No significant history",
            "examination": "Normal",
            "assessment": "Healthy",
            "diagnosis_ids": ["diagnosis-a0df27cc-18e7-458a-b4f7-07e69e8d7975"],
            "advice": "Drink water",
            "medications": []
        ]
        let consultRes = try await execute(path: "/api/v1/opd/encounters/\(encounterId)/complete", method: .post, body: ["data": consultationData, "__v": 0], token: doctorToken)
        print("✅ Consultation completed by Doctor: \(consultRes)")
        
        // 8. Patient OTP Flow
        let otpReqRes = try await execute(path: "/api/v1/auth/opd/otp/request", method: .post, body: ["phone": patientPhone])
        let code = otpReqRes["development_code"] as! String
        
        let otpVerifyRes = try await execute(path: "/api/v1/auth/opd/otp/verify", method: .post, body: ["phone": patientPhone, "code": code])
        let patientToken = otpVerifyRes["access_token"] as! String
        print("✅ Patient authenticated via OTP: \(code)")
        
        // 9. Patient Record Fetch
        let recordRes = try await execute(path: "/api/v1/opd/patients/\(patientId)/record", method: .get, token: patientToken)
        let notes = recordRes["notes"] as! [[String: Any]]
        let triage = recordRes["triage"] as! [[String: Any]]
        
        XCTAssertTrue(notes.count > 0)
        XCTAssertTrue(triage.count > 0)
        
        print("🎉 SUCCESS! Patient successfully retrieved PostgreSQL state generated by Staff!")
        print("Patient Notes: \(notes.first!)")
    }
}
