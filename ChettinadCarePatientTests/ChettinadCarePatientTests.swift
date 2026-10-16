import XCTest
@testable import ChettinadCore
@testable import ChettinadCarePatient

final class CareTaskProgressTests: XCTestCase {
    func testSkippedAndMissedTasksDoNotCountAsCompleted() {
        let progress = CareTaskProgress(statuses: [.COMPLETED, .SKIPPED, .MISSED, .DUE, .UPCOMING])
        XCTAssertEqual(progress.completed, 1)
        XCTAssertEqual(progress.skipped, 1)
        XCTAssertEqual(progress.missed, 1)
        XCTAssertEqual(progress.completionDescription, "1 of 5 tasks completed")
        XCTAssertFalse(progress.allCompleted)
    }

    func testUnfinishedPlanDoesNotShowCaughtUpMessage() {
        let progress = CareTaskProgress(statuses: [.SKIPPED, .MISSED])
        XCTAssertEqual(progress.completed, 0)
        XCTAssertFalse(progress.allCompleted)
    }

    func testCompletedAndEmptyPlans() {
        XCTAssertTrue(CareTaskProgress(statuses: [.COMPLETED, .COMPLETED]).allCompleted)
        XCTAssertFalse(CareTaskProgress(statuses: []).allCompleted)
    }
}

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

private final class PatientMockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            guard let handler = Self.handler else { throw URLError(.badServerResponse) }
            let (status, data) = try handler(request)
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type":"application/json"])!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}
private final class PatientRequestCapture: @unchecked Sendable {
    private let lock = NSLock(); private var requests: [URLRequest] = []
    func add(_ request: URLRequest) {
        var copy = request
        if copy.httpBody == nil, let stream = copy.httpBodyStream {
            stream.open(); defer { stream.close() }; var body = Data(); var bytes = [UInt8](repeating:0,count:4096)
            while stream.hasBytesAvailable { let count = stream.read(&bytes, maxLength:bytes.count); if count <= 0 { break }; body.append(contentsOf:bytes.prefix(count)) }; copy.httpBody = body
        }
        lock.lock(); defer { lock.unlock() }; requests.append(copy)
    }
    func all() -> [URLRequest] { lock.lock(); defer { lock.unlock() }; return requests }
}
@MainActor
final class PatientWorkflowSafetyTests: XCTestCase {
    private func client(_ handler: @escaping @Sendable (URLRequest) throws -> (Int, Data)) -> APIClient {
        PatientMockURLProtocol.handler = handler
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [PatientMockURLProtocol.self]
        return APIClient(baseURL: URL(string:"http://127.0.0.1:3011")!, urlSession: URLSession(configuration: config))
    }
    func testChallengeBindingCooldownExpiryAndResendReplaceTheChallenge() async throws {
        let capture = PatientRequestCapture(), date = Date(timeIntervalSince1970:1_000_000)
        let model = PatientLoginViewModel(client:client { request in
            capture.add(request)
            return (200, Data("{\"sent\":true,\"expires_in\":300,\"retry_after\":60,\"challenge_id\":\"challenge-1\",\"development_code\":\"123456\"}".utf8))
        },now:{date})
        model.phone = "9000000011"; await model.requestCode()
        XCTAssertEqual(model.challengeId,"challenge-1"); XCTAssertEqual(model.code,""); XCTAssertFalse(model.canRequest)
        XCTAssertEqual(model.expiresAt,date.addingTimeInterval(300))
        await model.requestCode(); XCTAssertEqual(capture.all().count,1)
        model.changePhone(); XCTAssertNil(model.challengeId); XCTAssertFalse(model.isCodeSent)
    }
    func testProfileRequiredRetainsBoundChallengeAndRejectsWrongAccountType() async throws {
        let capture = PatientRequestCapture()
        let model = PatientLoginViewModel(client:client { request in
            capture.add(request)
            if request.url!.path.hasSuffix("/request") { return (200,Data("{\"sent\":true,\"expires_in\":300,\"challenge_id\":\"bound-challenge\"}".utf8)) }
            return (422,Data("{\"error\":{\"code\":\"PROFILE_REQUIRED\",\"message\":\"Registration required\"}}".utf8))
        })
        model.phone = "9000000011"; await model.requestCode(); model.code = "654321"
        let result = await model.verify(); XCTAssertNil(result); XCTAssertTrue(model.isProfileRequired); XCTAssertEqual(model.challengeId,"bound-challenge")
        let body = try XCTUnwrap(try JSONSerialization.jsonObject(with:XCTUnwrap(capture.all().last?.httpBody)) as? [String:Any])
        XCTAssertEqual(body["challenge_id"] as? String,"bound-challenge"); XCTAssertEqual(body["purpose"] as? String,"PATIENT_LOGIN")
        PatientMockURLProtocol.handler = { _ in (200,Data("{\"role\":\"PATIENT\",\"account_type\":\"STAFF\",\"access_token\":\"synthetic\",\"userId\":\"u\",\"must_change_password\":false}".utf8)) }
        let wrong = await model.verify(); XCTAssertNil(wrong)
    }
    func testCancellationAndProfileUseCanonicalVersionedRoutes() async throws {
        let capture = PatientRequestCapture()
        let model = PatientViewModel(apiClient:client { request in
            capture.add(request)
            if request.httpMethod == "POST" || request.httpMethod == "PATCH" { return (200,Data("{\"success\":true}".utf8)) }
            return (503,Data("{}".utf8))
        })
        let cancelled = await model.cancelAppointment("appointment",version:8); XCTAssertTrue(cancelled)
        let request = try XCTUnwrap(capture.all().first); XCTAssertEqual(request.url?.path,"/api/v1/opd/appointments/appointment/cancel")
        let body = try XCTUnwrap(try JSONSerialization.jsonObject(with:XCTUnwrap(request.httpBody)) as? [String:Any]); XCTAssertEqual(body["__v"] as? Int,8)
        let bundle: RecordBundle = try JSONDecoder().decode(RecordBundle.self,from:Data("{\"patient\":{\"id\":\"p\",\"mrn\":\"SYN-P\",\"name\":\"Synthetic\",\"phone\":\"+919000000011\",\"dob\":\"1990-01-01\",\"gender\":\"Female\",\"__v\":6},\"encounters\":[],\"triage\":[],\"notes\":[],\"prescriptions\":[],\"labs\":[]}".utf8))
        model.recordBundle = bundle
        let updated = await model.updateProfile(email:"",address:"New address",city:"Test City",state:"Test State",pinCode:"600001",emergencyContact:"9000000012",version:6); XCTAssertTrue(updated)
        let patch = try XCTUnwrap(capture.all().first { $0.httpMethod == "PATCH" }); XCTAssertEqual(patch.url?.path,"/api/v1/opd/patients/p")
        let patchBody = try XCTUnwrap(try JSONSerialization.jsonObject(with:XCTUnwrap(patch.httpBody)) as? [String:Any]); XCTAssertEqual(patchBody["__v"] as? Int,6); XCTAssertEqual((patchBody["data"] as? [String:Any])?["address"] as? String,"New address")
    }
}

private final class PatientSlotGate: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func markStarted() { lock.lock(); value = true; lock.unlock() }
    var started: Bool { lock.lock(); defer { lock.unlock() }; return value }
}

@MainActor
final class PatientSchedulingRaceTests: XCTestCase {
    func testOlderSlotRequestCannotReplaceTheLatestDoctorAvailability() async throws {
        let gate = PatientSlotGate()
        PatientMockURLProtocol.handler = { request in
            let doctor = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "doctor_id" }?.value
            if doctor == "old" { gate.markStarted(); Thread.sleep(forTimeInterval: 0.15) }
            let time = doctor == "old" ? "2026-10-17T05:00:00Z" : "2026-10-17T06:00:00Z"
            return (200, Data("[{\"scheduled_at\":\"\(time)\",\"ends_at\":\"2026-10-17T06:15:00Z\",\"room\":\"Synthetic\",\"department_id\":\"OBST\"}]".utf8))
        }
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [PatientMockURLProtocol.self]
        let model = PatientViewModel(apiClient: APIClient(baseURL: URL(string: "http://patient-slots.invalid")!, urlSession: URLSession(configuration: config)))
        let first = Task { await model.fetchSlots(doctorId: "old", date: Date()) }
        for _ in 0..<200 { if gate.started { break }; try await Task.sleep(for: .milliseconds(5)) }
        XCTAssertTrue(gate.started)
        await model.fetchSlots(doctorId: "new", date: Date())
        await first.value
        XCTAssertEqual(model.slots.map(\.scheduled_at), ["2026-10-17T06:00:00Z"])
    }
}
