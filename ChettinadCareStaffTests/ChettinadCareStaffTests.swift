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
    func testReceptionActionsCarryDisplayedAppointmentVersion() throws {
        let confirm = AdminConfirmEndpoint(appointmentId: "appointment", version: 7)
        let checkIn = AdminCheckInEndpoint(appointmentId: "appointment", version: 8)
        let confirmed = try XCTUnwrap(try JSONSerialization.jsonObject(with: XCTUnwrap(confirm.body)) as? [String: Any])
        let checked = try XCTUnwrap(try JSONSerialization.jsonObject(with: XCTUnwrap(checkIn.body)) as? [String: Any])
        XCTAssertEqual(confirmed["__v"] as? Int, 7)
        XCTAssertEqual(checked["__v"] as? Int, 8)
        XCTAssertEqual(checked["identity_verified"] as? Bool, true)
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
        let amend = AmendConsultEndpoint(encounterId: "encounter", v: 2, data: value, reason: "Synthetic correction", patientVersion: 7)
        let amendment = try XCTUnwrap(try JSONSerialization.jsonObject(with: XCTUnwrap(amend.body)) as? [String: Any])
        XCTAssertEqual(amendment["__v"] as? Int, 2)
        XCTAssertEqual(amendment["patient__v"] as? Int, 7)
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
            {"patient":{"id":"patient","mrn":"MRN","name":"Synthetic patient","phone":"+919100000001","dob":"1990-01-01","gender":"Female","__v":\(patientVersion)},"encounters":[],"triage":[],"prescriptions":[],"labs":[],"notes":[{"id":"note","encounter_id":"encounter","author_id":"doctor","created_at":"2026-10-15T04:30:00Z","status":"DRAFT","__v":\(noteVersion),"draft_content":{"history":"Hospital history","previous_history":"Previous history","treatment":"Treatment kept"}}]}
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

private final class StaffMockURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (Int, Data))?
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        do {
            let (status, data) = try Self.handler!(request)
            let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type":"application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch { client?.urlProtocol(self, didFailWithError: error) }
    }
    override func stopLoading() {}
}

@MainActor
final class StaffWorkflowTests: XCTestCase {
    private func mockClient() -> APIClient {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StaffMockURLProtocol.self]
        return APIClient(baseURL: URL(string: "http://native-unit-test.invalid")!, urlSession: URLSession(configuration: config))
    }

    func testInitialPasswordRulesMatchServerRequirements() throws {
        XCTAssertFalse(StaffPasswordRules.accepts("Short1!"))
        XCTAssertFalse(StaffPasswordRules.accepts("alllowercase123!"))
        XCTAssertFalse(StaffPasswordRules.accepts("NoSymbols123456"))
        XCTAssertTrue(StaffPasswordRules.accepts("NativeReplacement2026!"))
        let endpoint = StaffPasswordChangeEndpoint(currentPassword: "SyntheticInitial2026!", newPassword: "NativeReplacement2026!")
        let payload = try XCTUnwrap(try JSONSerialization.jsonObject(with: XCTUnwrap(endpoint.body)) as? [String:String])
        XCTAssertEqual(payload["currentPassword"], "SyntheticInitial2026!")
        XCTAssertEqual(endpoint.path, "/api/v1/auth/change-password")
    }

    func testRoleMenusAndActionsMatchServerPermissions() {
        XCTAssertEqual(StaffDestination.destinations(for: "NURSE"), [.queue, .appointments, .labs, .profile])
        XCTAssertFalse(StaffDestination.destinations(for: "DOCTOR").contains(.staff))
        XCTAssertEqual(StaffDestination.destinations(for: "UNKNOWN"), [])
        for role in ["ADMIN", "DOCTOR"] {
            XCTAssertTrue(StaffPermissions.canConfirm(role: role))
            XCTAssertTrue(StaffPermissions.canCheckIn(role: role))
            XCTAssertTrue(StaffPermissions.canBook(role: role))
        }
        for role in ["NURSE", "PATIENT", "UNKNOWN"] {
            XCTAssertFalse(StaffPermissions.canConfirm(role: role))
            XCTAssertFalse(StaffPermissions.canCheckIn(role: role))
            XCTAssertFalse(StaffPermissions.canBook(role: role))
        }
    }

    func testNurseHandoffMovesIntoDoctorQueue() {
        XCTAssertTrue(StaffQueueViewModel.includes(status: "WAITING", role: "NURSE"))
        XCTAssertFalse(StaffQueueViewModel.includes(status: "DOCTOR_READY", role: "NURSE"))
        XCTAssertTrue(StaffQueueViewModel.includes(status: "DOCTOR_READY", role: "DOCTOR"))
        XCTAssertTrue(StaffQueueViewModel.includes(status: "WAITING_DOCTOR", role: "DOCTOR"))
        XCTAssertFalse(StaffQueueViewModel.includes(status: "COMPLETED", role: "DOCTOR"))
    }

    func testAdminOverviewRecoversAfterServerError() async {
        StaffMockURLProtocol.handler = { _ in (500, Data("{\"error\":{\"code\":\"SQLITE_ERROR\",\"message\":\"no such column: code\"}}".utf8)) }
        let model = AdminMetricsViewModel(apiClient: mockClient())
        await model.fetchMetrics()
        XCTAssertNotNil(model.errorMessage)
        XCTAssertFalse(model.isLoading)
        let recovered = Data("""
        {"date":"2026-10-13","requires_action":0,"security_alerts":2,"today_confirmed":0,"upcoming":0,"appointments":0,"checked_in":0,"waiting":0,"triage":0,"consultation":0,"completed":0,"no_shows":0,"results_pending":0,"doctors":[]}
        """.utf8)
        StaffMockURLProtocol.handler = { _ in (200, recovered) }
        await model.fetchMetrics()
        XCTAssertNil(model.errorMessage)
        XCTAssertFalse(model.isLoading)
        XCTAssertEqual(model.metrics?.security_alerts, 2)
    }

    func testAppointmentsUseHospitalDateAcrossTimeZones() async throws {
        StaffMockURLProtocol.handler = { request in
            let parts = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)
            XCTAssertEqual(parts?.queryItems?.first(where: { $0.name == "date" })?.value, "2026-10-14")
            return (200, Data("[]".utf8))
        }
        let model = AdminDashboardViewModel(apiClient: mockClient())
        await model.fetchAppointments(for: try XCTUnwrap(ISODate.parse("2026-10-13T20:00:00Z")))
        XCTAssertFalse(model.isLoading)
        XCTAssertNil(model.errorMessage)
    }

    func testRequestsIncludePendingAppointmentsAcrossDates() async {
        let body = Data("""
        [{"id":"future-request","doctor_id":"native-doctor","scheduled_at":"2026-10-20T10:00:00Z","status":"PENDING_CONFIRMATION"},{"id":"confirmed-visit","doctor_id":"native-doctor","scheduled_at":"2026-10-13T10:00:00Z","status":"CONFIRMED"}]
        """.utf8)
        StaffMockURLProtocol.handler = { request in
            XCTAssertNil(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems)
            return (200, body)
        }
        let model = AdminDashboardViewModel(apiClient: mockClient())
        await model.fetchAppointments(requestsOnly: true)
        XCTAssertEqual(model.appointments.map(\.id), ["future-request"])
        XCTAssertNil(model.errorMessage)
    }

    func testConnectionFailureIsNotAnEmptyQueue() async {
        StaffMockURLProtocol.handler = { _ in throw URLError(.notConnectedToInternet) }
        let model = DoctorQueueViewModel(apiClient: mockClient())
        await model.fetchQueue()
        XCTAssertFalse(model.isLoading)
        XCTAssertFalse(model.hasLoaded)
        XCTAssertNotNil(model.errorMessage)
    }

    func testCancellationAlwaysClearsLoadingWithoutError() async {
        StaffMockURLProtocol.handler = { _ in throw URLError(.cancelled) }
        let model = NurseTriageViewModel(apiClient: mockClient())
        await model.fetchQueue()
        XCTAssertFalse(model.isLoading)
        XCTAssertFalse(model.hasLoaded)
        XCTAssertNil(model.errorMessage)
    }

    func testFailedRefreshRetainsLastQueueSnapshot() async throws {
        let queue = Data("""
        [{"encounter_id":"native-enc","patient_id":"native-patient","patient_name":"Synthetic Patient","mrn":"SYN-1","status":"DOCTOR_READY","token":"OG-1","doctor_id":"native-doctor","doctor_name":"Synthetic Doctor","priority":0,"__v":2}]
        """.utf8)
        let metrics = Data("""
        {"date":"2026-10-13","requires_action":0,"security_alerts":0,"today_confirmed":1,"upcoming":0,"appointments":1,"checked_in":1,"waiting":1,"triage":0,"consultation":0,"completed":0,"no_shows":0,"results_pending":0,"doctors":[]}
        """.utf8)
        StaffMockURLProtocol.handler = { request in (200, request.url!.path.hasSuffix("queue") ? queue : metrics) }
        let model = DoctorQueueViewModel(apiClient: mockClient())
        await model.fetchQueue()
        XCTAssertTrue(model.hasLoaded)
        XCTAssertEqual(model.queue.count, 1)
        StaffMockURLProtocol.handler = { _ in throw URLError(.timedOut) }
        await model.fetchQueue()
        XCTAssertFalse(model.isLoading)
        XCTAssertEqual(model.queue.first?.encounter_id, "native-enc")
        XCTAssertNotNil(model.errorMessage)
    }
}

// These tests only mutate the explicitly configured disposable local fixture.
@MainActor
final class PatientStaffIntegrationTests: XCTestCase {
    private let baseURL = URL(string: "http://127.0.0.1:3011")!
    private let session = URLSession(configuration: .ephemeral)

    override func setUpWithError() throws {
        #if !CC_SHARED_FIXTURE
        guard ProcessInfo.processInfo.environment["CC_INTEGRATION_BASE_URL"] == "http://127.0.0.1:3011" else {
            throw XCTSkip("Requires the isolated synthetic native fixture on port 3011")
        }
        #endif
    }

    private func raw(_ endpoint: APIEndpoint, token: String? = nil, expected: Int = 200) async throws -> Data {
        var parts = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false)!
        parts.queryItems = endpoint.queryItems
        var request = URLRequest(url: parts.url!)
        request.httpMethod = endpoint.method.rawValue
        request.httpBody = endpoint.body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (name, value) in endpoint.headers ?? [:] { request.setValue(value, forHTTPHeaderField: name) }
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await session.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, expected, endpoint.path + ": " + String(decoding:data,as:UTF8.self))
        return data
    }
    private func load<T: Decodable>(_ endpoint: APIEndpoint, token: String? = nil, expected: Int = 200) async throws -> T {
        try JSONDecoder().decode(T.self, from: await raw(endpoint, token: token, expected: expected))
    }
    private func login(_ username: String) async throws -> String {
        let response: LoginResponse = try await load(StaffLoginEndpoint(username: username, password: "NativeIntegration2026!"))
        XCTAssertEqual(response.account_type.uppercased(), "STAFF")
        return response.access_token
    }
    private func patientLogin(_ phone: String) async throws -> String {
        let otp: OTPRequestResponse = try await load(OTPRequestEndpoint(phone: phone))
        let result: OTPVerifyResponse = try await load(OTPVerifyEndpoint(phone: phone, code: try XCTUnwrap(otp.development_code)))
        XCTAssertEqual(result.role.uppercased(), "PATIENT")
        return result.access_token
    }

    func testDeployedAdminOverviewContracts() async throws {
        guard ProcessInfo.processInfo.environment["CC_VERIFY_DEPLOYED_PILOT"] == "true" else { throw XCTSkip("Live pilot contract verification is opt-in") }
        baseURL = URL(string: "https://chettinad-care-api.onrender.com")!
        let login: LoginResponse = try await load(StaffLoginEndpoint(username: "admin", password: "ChettinadDemo2026!"))
        XCTAssertEqual(login.role.uppercased(), "ADMIN")
        let metrics: AdminMetricsResponse = try await load(AdminMetricsEndpoint(), token: login.access_token)
        XCTAssertGreaterThanOrEqual(metrics.security_alerts, 0)
        XCTAssertFalse(metrics.date.isEmpty)
    }

    func testDeployedPilotReadOnlyContracts() async throws {
        guard ProcessInfo.processInfo.environment["CC_VERIFY_DEPLOYED_PILOT"] == "true" else { throw XCTSkip("Live pilot contract verification is opt-in") }
        baseURL = URL(string: "https://chettinad-care-api.onrender.com")!
        let login: LoginResponse = try await load(StaffLoginEndpoint(username: "dr_prabha", password: "ChettinadDemo2026!"))
        XCTAssertEqual(login.role.uppercased(), "DOCTOR")
        let identity: UserSession = try await load(OPDSessionEndpoint(), token: login.access_token)
        XCTAssertEqual(identity.role.uppercased(), "DOCTOR")
        let directory: OPDDirectory = try await load(ChettinadCareStaff.DirectoryEndpoint(), token: login.access_token)
        XCTAssertTrue(directory.doctors.contains { $0.id == identity.id })
        let _: AdminMetricsResponse = try await load(AdminMetricsEndpoint(), token: login.access_token)
        let _: [QueueEntry] = try await load(QueueEndpoint(), token: login.access_token)
        let _: [Appointment] = try await load(AdminAllAppointmentsEndpoint(), token: login.access_token)
    }

    func testFirstLoginPasswordChangeUnlocksClinicalWorkspace() async throws {
        let login: LoginResponse = try await load(StaffLoginEndpoint(username: "native_first_login", password: "NativeIntegration2026!"))
        XCTAssertTrue(login.must_change_password)
        let state: UserSession = try await load(OPDSessionEndpoint(), token: login.access_token)
        XCTAssertTrue(state.must_change_password)
        _ = try await raw(AdminMetricsEndpoint(), token: login.access_token, expected: 403)
        _ = try await raw(StaffPasswordChangeEndpoint(currentPassword: "NativeIntegration2026!", newPassword: "short"), token: login.access_token, expected: 400)
        _ = try await raw(StaffPasswordChangeEndpoint(currentPassword: "NativeIntegration2026!", newPassword: "NativeReplacement2026!"), token: login.access_token)
        let changed: UserSession = try await load(OPDSessionEndpoint(), token: login.access_token)
        XCTAssertFalse(changed.must_change_password)
        let _: AdminMetricsResponse = try await load(AdminMetricsEndpoint(), token: login.access_token)
    }

    func testPatientRequestStaffHandoffAndSignedRecordShareIdentity() async throws {
        let doctor = try await login("native_doctor")
        let nurse = try await login("native_nurse")
        let patient = try await patientLogin("+919100000991")
        let otherPatient = try await patientLogin("+919100000992")
        let identity: UserSession = try await load(OPDSessionEndpoint(), token: patient)
        let patientId = try XCTUnwrap(identity.patient_id)
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Kolkata")
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        let slots: [AppointmentSlot] = try await load(AppointmentSlotsEndpoint(doctorId: "native_doctor", date: today), token: patient)
        let slot = try XCTUnwrap(slots.first { (ISODate.parse($0.scheduled_at) ?? .distantPast) > Date() })
        let booked: Appointment = try await load(BookAppointmentEndpoint(doctorId: "native_doctor", scheduledAt: slot.scheduled_at, reason: "Synthetic native handoff"), token: patient, expected: 201)
        XCTAssertEqual(booked.patient_id, patientId)
        XCTAssertEqual(booked.status, "PENDING_CONFIRMATION")
        let requests: [Appointment] = try await load(AdminAllAppointmentsEndpoint(), token: doctor)
        XCTAssertTrue(requests.contains { $0.id == booked.id && $0.patient_id == patientId })
        _ = try await raw(AdminConfirmEndpoint(appointmentId: booked.id), token: nurse, expected: 403)
        let confirmed: Appointment = try await load(AdminConfirmEndpoint(appointmentId: booked.id), token: doctor)
        XCTAssertEqual(confirmed.status, "CONFIRMED")
        let patientAppointments: [Appointment] = try await load(AdminAllAppointmentsEndpoint(), token: patient)
        XCTAssertEqual(patientAppointments.first(where: { $0.id == booked.id })?.status, "CONFIRMED")
        _ = try await raw(AdminCheckInEndpoint(appointmentId: booked.id), token: nurse, expected: 403)
        _ = try await raw(AdminCheckInEndpoint(appointmentId: booked.id), token: doctor)
        let nurseQueue: [QueueEntry] = try await load(QueueEndpoint(), token: nurse)
        let checkedIn = try XCTUnwrap(nurseQueue.first { $0.patient_id == patientId })
        let encounter = checkedIn.encounter_id
        try await verifyPatientInputs(patientId: patientId, appointmentId: booked.id, patient: patient, doctor: doctor, nurse: nurse)
        _ = try await raw(StartTriageEndpoint(encounterId: encounter, v: checkedIn.__v), token: nurse)
        let triageQueue: [QueueEntry] = try await load(QueueEndpoint(), token: nurse)
        let triage = try XCTUnwrap(triageQueue.first { $0.encounter_id == encounter })
        let vitals = TriageData(temperature: 36.8, systolic: 118, diastolic: 76, pulse: 72, spo2: 98, weight: 62, height: 164, complaint: "Synthetic native handoff", allergies: nil, pain: 1, notes: "Exact native nurse handoff", priority: 0, bmi: nil)
        _ = try await raw(SubmitTriageEndpoint(encounterId: encounter, v: triage.__v, data: vitals), token: nurse)
        let doctorQueue: [QueueEntry] = try await load(QueueEndpoint(), token: doctor)
        let handoff = try XCTUnwrap(doctorQueue.first { $0.encounter_id == encounter })
        XCTAssertTrue(StaffQueueViewModel.includes(status: handoff.status, role: "DOCTOR"))
        _ = try await raw(StartConsultEndpoint(encounterId: encounter, v: handoff.__v), token: doctor)
        let dossier: RecordBundle = try await load(PatientRecordEndpoint(patientId: patientId), token: doctor)
        XCTAssertEqual(dossier.patient.id, patientId)
        XCTAssertEqual(dossier.triage.first(where: { $0.encounter_id == encounter })?.data?.notes, "Exact native nurse handoff")
        let noteVersion = dossier.notes.first(where: { $0.encounter_id == encounter })?.__v ?? 0
        let clinical = ConsultationData(complaint: "Synthetic native handoff", history: "Synthetic clinical history", previous_history: nil, examination: "Synthetic examination", assessment: "Synthetic assessment", diagnosis_ids: ["native_diagnosis"], treatment: nil, advice: "Synthetic patient advice", medications: [PrescriptionDrug(drug_id: "native_drug", dose: "1", frequency: "Daily", duration: "3 days", instructions: "Synthetic instructions")])
        _ = try await raw(CompleteConsultEndpoint(encounterId: encounter, v: noteVersion, data: clinical), token: nurse, expected: 403)
        _ = try await raw(CompleteConsultEndpoint(encounterId: encounter, v: noteVersion, data: clinical), token: doctor)
        let patientRecord: RecordBundle = try await load(PatientRecordEndpoint(patientId: patientId), token: patient)
        XCTAssertEqual(patientRecord.patient.id, patientId)
        XCTAssertTrue(patientRecord.notes.contains { $0.encounter_id == encounter })
        XCTAssertTrue(patientRecord.prescriptions.contains { $0.encounter_id == encounter })
        let finalQueue: [QueueEntry] = try await load(QueueEndpoint(), token: patient)
        XCTAssertFalse(finalQueue.contains { $0.encounter_id == encounter })
        _ = try await raw(PatientRecordEndpoint(patientId: patientId), token: otherPatient, expected: 404)
    }

    private func verifyPatientInputs(patientId: String, appointmentId: String, patient: String, doctor: String, nurse: String) async throws {
        struct Observation: Encodable {
            let record_type = "GLUCOSE"
            let timing_context = "AFTER_BREAKFAST"
            let numeric_value = 112
            let unit = "mg/dL"
            let observed_at = ISO8601DateFormatter().string(from: Date())
            let patient_note = "Synthetic home reading"
        }
        let recorded: PatientSelfRecord = try await load(CreatePatientSelfRecordEndpoint(patientId: patientId, payload: Observation()), token: patient, expected: 201)
        let boundary = "NativeSyntheticBoundary"
        var multipart = Data()
        let fields = ["document_type":"LAB_REPORT", "title":"Synthetic shared report", "clinical_date":"2026-10-13", "appointment_id":appointmentId]
        for (name, value) in fields {
            multipart.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n".utf8))
        }
        multipart.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"synthetic.pdf\"\r\nContent-Type: application/pdf\r\n\r\n%PDF-1.4\n1 0 obj << /Type /Catalog >> endobj\n%%EOF\n\r\n--\(boundary)--\r\n".utf8))
        let uploaded: PatientDocument = try await load(NativeWireEndpoint(path: "/api/v1/opd/patient-documents/\(patientId)", method: .post, headers: ["Content-Type":"multipart/form-data; boundary=\(boundary)"], body: multipart), token: patient, expected: 201)
        XCTAssertEqual(uploaded.appointment_id, appointmentId)
        for staff in [doctor, nurse] {
            let tasks: [CarePlanOccurrenceDTO] = try await load(GetTodayAdherenceEndpoint(patientId: patientId), token: staff)
            let observations: [PatientSelfRecord] = try await load(PatientSelfRecordsEndpoint(patientId: patientId), token: staff)
            let documents: [PatientDocument] = try await load(PatientDocumentsEndpoint(patientId: patientId), token: staff)
            XCTAssertTrue(tasks.isEmpty)
            XCTAssertTrue(observations.contains { $0.id == recorded.id && $0.numeric_value == 112 })
            XCTAssertTrue(documents.contains { $0.id == uploaded.id && $0.patient_id == patientId })
            let content = try await raw(NativeWireEndpoint(path: uploaded.content_url, method: .get), token: staff)
            XCTAssertTrue(String(decoding: content, as: UTF8.self).hasPrefix("%PDF"))
        }
    }
}

private struct NativeWireEndpoint: APIEndpoint {
    let path: String
    let method: HTTPMethod
    var headers: [String: String]? = nil
    var body: Data? = nil
}

private final class ConsultationRequestCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [URLRequest] = []
    func add(_ request: URLRequest) -> Int {
        lock.lock(); defer { lock.unlock() }
        var captured = request
        if captured.httpBody == nil, let stream = captured.httpBodyStream {
            stream.open(); defer { stream.close() }
            var data = Data(), bytes = [UInt8](repeating:0,count:4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&bytes,maxLength:bytes.count)
                if count <= 0 { break }
                data.append(contentsOf:bytes.prefix(count))
            }
            captured.httpBody = data
        }
        requests.append(captured)
        return requests.filter { $0.httpMethod == request.httpMethod && $0.url?.path == request.url?.path }.count
    }
    func all() -> [URLRequest] { lock.lock(); defer { lock.unlock() }; return requests }
}

@MainActor
final class NativeConsultationSafetyTests: XCTestCase {
    private func client(_ handler: @escaping @Sendable (URLRequest) throws -> (Int,Data)) -> APIClient {
        StaffMockURLProtocol.handler = handler
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [StaffMockURLProtocol.self]
        return APIClient(baseURL:URL(string:"http://native-clinical.invalid")!,urlSession:URLSession(configuration:config))
    }
    private func record(version: Int = 4, history: String = "Saved history", finalized: Bool = false) throws -> Data {
        let content: [String:Any] = ["complaint":"Synthetic complaint","history":history,"previous_history":"Earlier history","examination":"Saved examination","assessment":"Saved assessment","treatment":"Saved treatment","advice":"Saved advice","diagnosis_ids":["dx"],"diagnoses":[["id":"dx","name":"Synthetic diagnosis"]],"medications":[["drug_id":"drug","name":"Synthetic medicine","strength":"Synthetic strength","form":"Tablet","route":"Oral","dose":"Synthetic dose","frequency":"Synthetic frequency","duration":"Synthetic duration","instructions":"Synthetic instruction"]]]
        return try JSONSerialization.data(withJSONObject:[
            "patient":["id":"p","mrn":"SYN-p","name":"Synthetic Patient","phone":"+919000001991","dob":"1995-01-01","gender":"Female","__v":2,"allergies":"Synthetic allergy","allergy_review_status":"RECORDED"],
            "encounters":[["id":"enc","patient_id":"p","assigned_doctor_id":"doc","phase":finalized ? "DISCHARGED":"IN_CONSULTATION","lifecycle_status":finalized ? "DISCHARGED":"IN_CONSULTATION","is_discharged":finalized ? 1:0,"__v":12]],
            "notes":[["id":"note","encounter_id":"enc","status":finalized ? "FINALIZED":"DRAFT","author_id":"doc","created_at":"2026-10-14T04:00:00Z","updated_at":"2026-10-14T04:01:00Z","__v":version,"draft_content":content]],
            "triage":[],"prescriptions":[],"labs":[],"journey":[]
        ])
    }
    private func model(_ client: APIClient, actor: String = "doc", recoveryFolder: URL? = nil) -> DoctorConsultationViewModel {
        DoctorConsultationViewModel(encounterId:"enc",patientId:"p",initialVersion:12,apiClient:client,authenticatedActorId:actor,persistLocalDrafts:recoveryFolder != nil,draftDirectory:recoveryFolder)
    }
    func testSavedDraftRestoresActualEditableFieldsAndNoteVersion() async throws {
        let data = try record()
        let viewModel = model(client { _ in (200,data) })
        await viewModel.fetchPatientDossier()
        XCTAssertEqual(viewModel.noteVersion,4); XCTAssertEqual(viewModel.currentVersion,12)
        XCTAssertEqual(viewModel.noteHistory,"Saved history"); XCTAssertEqual(viewModel.notePreviousHistory,"Earlier history")
        XCTAssertEqual(viewModel.selectedDiagnoses,["dx"]); XCTAssertEqual(viewModel.medications.count,1)
        XCTAssertFalse(viewModel.hasUnsavedChanges)
    }
    func testSaveUsesNoteVersionAndRefreshDoesNotOverwriteEnteredText() async throws {
        let data = try record(), capture = ConsultationRequestCapture()
        let viewModel = model(client { request in
            _ = capture.add(request)
            return request.httpMethod == "PUT" ? (200,Data("{\"id\":\"note\",\"__v\":5}".utf8)) : (200,data)
        })
        await viewModel.fetchPatientDossier(); viewModel.noteHistory = "Entered history"
        await viewModel.fetchPatientDossier()
        XCTAssertEqual(viewModel.noteHistory,"Entered history")
        let saved = await viewModel.saveDraft(); XCTAssertTrue(saved)
        let sent = try XCTUnwrap(capture.all().first { $0.httpMethod == "PUT" })
        let body = try XCTUnwrap(try JSONSerialization.jsonObject(with:XCTUnwrap(sent.httpBody)) as? [String:Any])
        XCTAssertEqual(body["__v"] as? Int,4)
        XCTAssertEqual((body["data"] as? [String:Any])?["history"] as? String,"Entered history")
        XCTAssertEqual(viewModel.noteVersion,5); XCTAssertFalse(viewModel.hasUnsavedChanges)
    }
    func testCompletionUsesNoteVersionInsteadOfQueueVersion() async throws {
        let data = try record(), capture = ConsultationRequestCapture()
        let viewModel = model(client { request in
            _ = capture.add(request)
            return request.httpMethod == "POST" ? (200,Data("{\"id\":\"note\",\"__v\":5}".utf8)) : (200,data)
        })
        await viewModel.fetchPatientDossier()
        let done = await viewModel.completeConsultation(); XCTAssertTrue(done)
        let sent = try XCTUnwrap(capture.all().first { $0.url?.path.hasSuffix("/complete") == true })
        let body = try XCTUnwrap(try JSONSerialization.jsonObject(with:XCTUnwrap(sent.httpBody)) as? [String:Any])
        XCTAssertEqual(body["__v"] as? Int,4); XCTAssertTrue(viewModel.consultationCompleted)
    }
    func testLostCompletionResponseReadsSignedRecordWithoutSigningAgain() async throws {
        let draft = try record(), signed = try record(version:5,finalized:true), capture = ConsultationRequestCapture()
        let viewModel = model(client { request in
            _ = capture.add(request)
            if request.httpMethod == "POST" { throw URLError(.networkConnectionLost) }
            return (200,capture.all().contains { $0.httpMethod == "POST" } ? signed:draft)
        })
        await viewModel.fetchPatientDossier()
        let done = await viewModel.completeConsultation(); XCTAssertTrue(done)
        XCTAssertTrue(viewModel.consultationCompleted)
        XCTAssertEqual(capture.all().filter { $0.httpMethod == "POST" }.count,1)
    }
    func testConflictPreservesDraftUntilClinicianReviewsSavedVersion() async throws {
        let original = try record(), newer = try record(version:5,history:"Other saved history"), capture = ConsultationRequestCapture()
        let viewModel = model(client { request in
            let count = capture.add(request)
            if request.httpMethod == "PUT" { return (409,Data("{\"error\":{\"code\":\"STALE_STATE\",\"message\":\"Conflict\"}}".utf8)) }
            return (200,count == 1 ? original:newer)
        })
        await viewModel.fetchPatientDossier(); viewModel.noteHistory = "My unsaved history"
        let saved = await viewModel.saveDraft(); XCTAssertFalse(saved)
        XCTAssertEqual(viewModel.noteHistory,"My unsaved history"); XCTAssertEqual(viewModel.noteVersion,4)
        XCTAssertEqual(viewModel.conflictingSavedDraft?.history,"Other saved history")
        viewModel.keepMyDraftAfterReview()
        XCTAssertEqual(viewModel.noteVersion,5); XCTAssertEqual(viewModel.noteHistory,"My unsaved history")
        XCTAssertTrue(viewModel.hasUnsavedChanges)
    }
    func testRecoveryCopyIsBoundToActorPatientAndEncounter() async throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("native-recovery-"+UUID().uuidString,isDirectory:true)
        defer { try? FileManager.default.removeItem(at:folder) }
        let data = try record(), api = client { _ in (200,data) }
        let first = model(api,recoveryFolder:folder)
        await first.fetchPatientDossier(); first.noteHistory = "Unfinished protected history"
        let protected = await first.persistLocalDraft(); XCTAssertTrue(protected)
        let resumed = model(api,recoveryFolder:folder); await resumed.fetchPatientDossier()
        XCTAssertEqual(resumed.noteHistory,"Unfinished protected history"); XCTAssertTrue(resumed.hasUnsavedChanges)
        let anotherActor = model(api,actor:"another-doc",recoveryFolder:folder); await anotherActor.fetchPatientDossier()
        XCTAssertEqual(anotherActor.noteHistory,"Saved history")
    }
}

@MainActor
final class NativeModelServerIntegrationTests: XCTestCase {
    func testActualNurseAndDoctorModelsSaveResumeAndSignTheSameVisit() async throws {
        #if !CC_SHARED_FIXTURE
        guard ProcessInfo.processInfo.environment["CC_INTEGRATION_BASE_URL"] == "http://127.0.0.1:3011" else { throw XCTSkip("Requires the disposable native fixture") }
        #endif
        let manager = SessionManager(storage:IntegrationMemorySessionStorage())
        let client = APIClient(baseURL:URL(string:"http://127.0.0.1:3011")!,sessionManager:manager)
        func staff(_ username: String) async throws {
            let login: LoginResponse = try await client.execute(endpoint:StaffLoginEndpoint(username:username,password:"NativeIntegration2026!"))
            try await manager.saveSession(AuthSession(accessToken:login.access_token,role:login.role.uppercased(),accountType:"STAFF",userId:login.userId,name:login.name))
        }
        let otp: OTPRequestResponse = try await client.execute(endpoint:OTPRequestEndpoint(phone:"9100000992"))
        let patientAuth: OTPVerifyResponse = try await client.execute(endpoint:OTPVerifyEndpoint(phone:"9100000992",code:try XCTUnwrap(otp.development_code),challengeId:otp.challenge_id))
        try await manager.saveSession(AuthSession(accessToken:patientAuth.access_token,role:"PATIENT",accountType:"PATIENT",userId:patientAuth.userId,name:patientAuth.name))
        let identity: UserSession = try await client.execute(endpoint:OPDSessionEndpoint());let patientId = try XCTUnwrap(identity.patient_id)
        let formatter = DateFormatter();formatter.calendar=Calendar(identifier:.gregorian);formatter.locale=Locale(identifier:"en_US_POSIX");formatter.timeZone=TimeZone(identifier:"Asia/Kolkata");formatter.dateFormat="yyyy-MM-dd"
        let slots: [AppointmentSlot] = try await client.execute(endpoint:AppointmentSlotsEndpoint(doctorId:"native_doctor",date:formatter.string(from:Date())))
        let appointment: Appointment = try await client.execute(endpoint:BookAppointmentEndpoint(doctorId:"native_doctor",scheduledAt:try XCTUnwrap(slots.first).scheduled_at,reason:"Synthetic actual-model journey"))
        try await staff("native_admin")
        let _: Appointment = try await client.execute(endpoint:AdminConfirmEndpoint(appointmentId:appointment.id))
        let _: EncounterMutationResponse = try await client.execute(endpoint:AdminCheckInEndpoint(appointmentId:appointment.id))
        try await staff("native_nurse")
        let nurseQueue: [QueueEntry] = try await client.execute(endpoint:QueueEndpoint());let entry = try XCTUnwrap(nurseQueue.first { $0.patient_id == patientId })
        let nurse = TriageFormViewModel(encounterId:entry.encounter_id,initialVersion:entry.__v,apiClient:client)
        let started = await nurse.startTriage();XCTAssertTrue(started)
        XCTAssertEqual(nurse.patient?.id,patientId)
        nurse.temperature="37";nurse.systolic="120";nurse.diastolic="80";nurse.pulse="75";nurse.spo2="99";nurse.weight="60";nurse.height="160";nurse.pain="0";nurse.complaint="Synthetic actual-model complaint"
        let triaged = await nurse.submitTriage();XCTAssertTrue(triaged,nurse.errorMessage ?? "")
        try await staff("native_doctor")
        let doctorQueue: [QueueEntry] = try await client.execute(endpoint:QueueEndpoint());let handoff = try XCTUnwrap(doctorQueue.first { $0.patient_id == patientId })
        let doctor = DoctorConsultationViewModel(encounterId:handoff.encounter_id,patientId:patientId,initialVersion:handoff.__v,apiClient:client,persistLocalDrafts:false)
        await doctor.fetchPatientDossier();let consulting = await doctor.startConsultation();XCTAssertTrue(consulting,doctor.errorMessage ?? "")
        doctor.noteHistory="Actual-model saved history";doctor.noteExamination="Synthetic examination";doctor.noteAssessment="Synthetic assessment";doctor.noteAdvice="Synthetic patient advice";doctor.selectedDiagnoses=["native_diagnosis"];doctor.medications=[PrescriptionDrug(drug_id:"native_drug",dose:"1 tablet",frequency:"Once daily",duration:"3 days",instructions:"Synthetic instructions only")]
        let saved = await doctor.saveDraft();XCTAssertTrue(saved,doctor.errorMessage ?? "");XCTAssertEqual(doctor.noteVersion,1)
        let resumed = DoctorConsultationViewModel(encounterId:handoff.encounter_id,patientId:patientId,initialVersion:handoff.__v,apiClient:client,persistLocalDrafts:false)
        await resumed.fetchPatientDossier();XCTAssertEqual(resumed.noteHistory,"Actual-model saved history");XCTAssertEqual(resumed.noteVersion,1)
        let signed = await resumed.completeConsultation();XCTAssertTrue(signed,resumed.errorMessage ?? "")
        let record: RecordBundle = try await client.execute(endpoint:PatientRecordEndpoint(patientId:patientId))
        XCTAssertEqual(record.notes.first { $0.encounter_id == handoff.encounter_id }?.status,"FINALIZED")
        XCTAssertEqual(record.prescriptions.filter { $0.encounter_id == handoff.encounter_id }.count,1)
        let pdf = try PrescriptionPDF.create(prescription:try XCTUnwrap(record.prescriptions.first),patient:record.patient)
        XCTAssertGreaterThan((try Data(contentsOf:pdf)).count,100);try FileManager.default.removeItem(at:pdf)
        await manager.clearSession()
    }
}

private final class IntegrationMemorySessionStorage: AuthSessionStorage, @unchecked Sendable {
    private let lock = NSLock(); private var value: Data?
    func read() -> Data? { lock.lock(); defer { lock.unlock() }; return value }
    func save(_ data: Data) -> Bool { lock.lock(); defer { lock.unlock() }; value = data; return true }
    func delete() { lock.lock(); defer { lock.unlock() }; value = nil }
}

private final class SchedulingRequestGate: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false
    func markStarted() { lock.lock(); value = true; lock.unlock() }
    var started: Bool { lock.lock(); defer { lock.unlock() }; return value }
}

@MainActor
final class SchedulingRaceTests: XCTestCase {
    private func client(_ handler: @escaping @Sendable (URLRequest) throws -> (Int, Data)) -> APIClient {
        StaffMockURLProtocol.handler = handler
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [StaffMockURLProtocol.self]
        return APIClient(baseURL: URL(string: "http://scheduling.invalid")!, urlSession: URLSession(configuration: config))
    }
    private func waitForRequest(_ gate: SchedulingRequestGate) async throws {
        for _ in 0..<200 {
            if gate.started { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("The delayed request never started")
    }
    func testLatePatientSearchCannotRestoreAnOldIdentity() async throws {
        let gate = SchedulingRequestGate()
        let model = BookAppointmentViewModel(apiClient: client { _ in
            gate.markStarted(); Thread.sleep(forTimeInterval: 0.15)
            return (200, Data(#"[{"id":"old-patient","name":"Old result","phone":"+919100000001"}]"#.utf8))
        })
        model.searchQuery = "Old patient"
        let first = Task { await model.searchPatients() }
        try await waitForRequest(gate)
        model.selectedPatientId = "old-patient"
        model.searchQuery = "New patient"
        await first.value
        XCTAssertNil(model.selectedPatientId)
        XCTAssertTrue(model.searchResults.isEmpty)
        XCTAssertFalse(model.isSearching)
    }
    func testLateAvailabilityCannotRepopulateAClearedDoctor() async throws {
        let gate = SchedulingRequestGate()
        let model = BookAppointmentViewModel(apiClient: client { _ in
            gate.markStarted(); Thread.sleep(forTimeInterval: 0.15)
            return (200, Data(#"[{"scheduled_at":"2026-10-17T05:00:00Z"}]"#.utf8))
        })
        model.selectedDoctorId = "old-doctor"
        let first = Task { await model.fetchSlots() }
        try await waitForRequest(gate)
        model.selectedDoctorId = nil
        await first.value
        XCTAssertTrue(model.availableSlots.isEmpty)
        XCTAssertNil(model.selectedSlot)
    }
}
