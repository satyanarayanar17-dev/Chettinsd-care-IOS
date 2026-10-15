import SwiftUI
import ChettinadCore

// MARK: - Response DTOs

struct EncounterMutationResponse: Codable {
    let encounter_id: String?
    let __v: Int?
    let phase: String?
}

struct NoteResponse: Codable {
    let id: String?
    let status: String?
    let __v: Int?
}

// MARK: - Endpoints

struct StartConsultEndpoint: APIEndpoint {
    let encounterId: String
    let v: Int
    var path: String { "/api/v1/opd/encounters/\(encounterId)/start" }
    var method: HTTPMethod { .post }
    var body: Data? { try? JSONSerialization.data(withJSONObject: ["__v": v]) }
}

struct CompleteConsultEndpoint: APIEndpoint {
    let encounterId: String
    let v: Int
    let data: ConsultationData
    let patientVersion: Int
    var path: String { "/api/v1/opd/encounters/\(encounterId)/complete" }
    var method: HTTPMethod { .post }
    var body: Data? {
        let payload = CompletePayload(__v: v, data: data, patient__v: patientVersion)
        return try? JSONEncoder().encode(payload)
    }
}

struct AmendConsultEndpoint: APIEndpoint {
    typealias Response = EncounterMutationResponse
    let encounterId: String
    let v: Int
    let patientVersion: Int
    let data: ConsultationData
    let reason: String
    var path: String { "/api/v1/opd/encounters/\(encounterId)/amend" }
    var method: HTTPMethod { .post }
    var body: Data? {
        struct AmendPayload: Codable {
            let __v: Int
            let data: ConsultationData
            let reason: String
            let patient__v: Int
        }
        return try? JSONEncoder().encode(AmendPayload(__v: v, data: data, reason: reason, patient__v: patientVersion))
    }
}


struct CompletePayload: Codable {
    let __v: Int
    let data: ConsultationData
    let patient__v: Int
}

struct ConsultationData: Codable {
    let complaint: String?
    let history: String?
    let previous_history: String?
    let examination: String?
    let assessment: String?
    let diagnosis_ids: [String]
    let treatment: String?
    let advice: String?
    let medications: [PrescriptionDrug]
    let follow_up: ConsultationFollowUp?
}

struct PrescriptionDrug: Codable {
    let drug_id: String
    let dose: String
    let frequency: String
    let duration: String
    let instructions: String?
}

struct PatientRecordEndpoint: APIEndpoint {
    let patientId: String
    var path: String { "/api/v1/opd/patients/\(patientId)/record" }
    var method: HTTPMethod { .get }
}

// MARK: - Queue ViewModel

@MainActor
class DoctorQueueViewModel: ObservableObject {
    @Published var queue: [QueueEntry] = []
    @Published var appointments: [Appointment] = []
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    @Published var metrics: AdminMetricsResponse? = nil
    
    let apiClient = APIClient()
    var pendingAppointments: [Appointment] {
        appointments.filter { $0.status == "PENDING_CONFIRMATION" }.sorted { $0.scheduled_at < $1.scheduled_at }
    }
    
    var todayAppointments: [Appointment] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        formatter.timeZone = TimeZone(identifier: "Asia/Kolkata")
        let today = formatter.string(from: Date())
        
        return appointments.filter { 
            ($0.status == "CONFIRMED" || $0.status == "CHECKED_IN" || $0.status == "READY_FOR_DOCTOR" || $0.status == "IN_CONSULTATION") && 
            $0.scheduled_at.hasPrefix(today)
        }.sorted { $0.scheduled_at < $1.scheduled_at }
    }
    
    private func appointmentVersion(_ id: String) throws -> Int {
        guard let appointment = appointments.first(where: { $0.id == id }), let version = appointment.__v else { throw APIError.invalidResponse }
        return version
    }

    func confirmAppointment(appointmentId: String) async {
        do {
            struct AnyResponse: Codable {}
            let _: AnyResponse = try await apiClient.execute(endpoint: AdminConfirmEndpoint(appointmentId: appointmentId, version: try appointmentVersion(appointmentId)))
            await fetchQueue()
        } catch {
            self.errorMessage = "Confirm failed: \(error.localizedDescription)"
        }
    }
    
    func checkIn(appointmentId: String) async {
        do {
            struct AnyResponse: Codable {}
            let _: AnyResponse = try await apiClient.execute(endpoint: AdminCheckInEndpoint(appointmentId: appointmentId, version: try appointmentVersion(appointmentId)))
            await fetchQueue()
        } catch {
            self.errorMessage = "Check-in failed: \(error.localizedDescription)"
        }
    }

    
    private var queueFetchInFlight = false
    func fetchQueue() async {
        guard !queueFetchInFlight else { return }
        queueFetchInFlight = true
        defer { queueFetchInFlight = false; isLoading = false }
        if metrics == nil { isLoading = true }
        errorMessage = nil
        do {
            async let fetchedQueueTask: [QueueEntry] = try await apiClient.execute(endpoint: QueueEndpoint())
            async let metricsTask: AdminMetricsResponse = try await apiClient.execute(endpoint: AdminMetricsEndpoint())
            async let appointmentsTask: [Appointment] = {
                do {
                    return try await apiClient.execute(endpoint: AdminAllAppointmentsEndpoint())
                } catch {
                    print("Appointments error:", error)
                    return []
                }
            }()
            let (fetchedQueue, metrics, fetchedAppointments) = try await (fetchedQueueTask, metricsTask, appointmentsTask)
            self.metrics = metrics
            self.appointments = fetchedAppointments
            self.queue = fetchedQueue.filter { $0.status == "WAITING_DOCTOR" || $0.status == "DOCTOR_READY" || $0.status == "CONSULTATION" }
        } catch {
            if error is CancellationError { return }
            if (error as NSError).domain == NSURLErrorDomain && (error as NSError).code == NSURLErrorCancelled { return }
            self.errorMessage = error.localizedDescription
        }
        isLoading = false

    }
}

// MARK: - Consultation ViewModel

@MainActor
class DoctorConsultationViewModel: ObservableObject {
    @Published var recordBundle: RecordBundle?
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    
    @Published var currentVersion: Int
    let encounterId: String?
    let patientId: String
    
    // Consultation note fields
    @Published var noteComplaint = ""
    @Published var noteHistory = ""
    private var notePreviousHistory = ""
    private var noteTreatment = ""
    private var noteFollowUp: ConsultationFollowUp?
    @Published var noteVersion = 0
    private var hasLoadedDraft = false
    private var reviewedPatientVersion: Int?
    @Published var recordChangedElsewhere = false
    private var dossierFetchInFlight = false
    @Published var noteExamination = ""
    @Published var noteAssessment = ""
    @Published var noteAdvice = ""
    @Published var isSubmitting = false
    
    // Catalogues
    @Published var catalogues: CataloguesResponse?
    @Published var selectedDiagnoses: Set<String> = []
    @Published var medications: [PrescriptionDrug] = []
    @Published var labOrdersInFlight: Set<String> = []
    /// Set only after "Complete & Sign" succeeds; the dossier closes only in that case.
    @Published var consultationCompleted = false
    @Published var amendReason: String = ""


    /// Lab tests already ordered on this encounter.
    var orderedTestIds: Set<String> {
        Set(recordBundle?.labs.filter { $0.encounter_id == encounterId }.map(\.test_id) ?? [])
    }
    
    let apiClient = APIClient()
    
    init(encounterId: String?, patientId: String, initialVersion: Int) {
        self.encounterId = encounterId
        self.patientId = patientId
        self.currentVersion = initialVersion
    }
    
    func fetchCatalogues() async {
        do {
            let cat: CataloguesResponse = try await apiClient.execute(endpoint: CataloguesEndpoint())
            self.catalogues = cat
        } catch {
            self.errorMessage = "Failed to fetch catalogues: \(error.localizedDescription)"
        }
    }
    
    func fetchPatientDossier() async {
        guard !isSubmitting, !dossierFetchInFlight else { return }
        dossierFetchInFlight = true
        defer { dossierFetchInFlight = false; isLoading = false }
        if recordBundle == nil { isLoading = true }
        errorMessage = nil
        do {
            let bundle: RecordBundle = try await apiClient.execute(
                endpoint: PatientRecordEndpoint(patientId: patientId)
            )
            acceptDossier(bundle)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func acceptDossier(_ bundle: RecordBundle) {
        self.recordBundle = bundle
        let note = bundle.notes.first(where: { $0.encounter_id == encounterId })
        let remoteVersion = note?.__v ?? 0
        if !hasLoadedDraft {
            noteVersion = remoteVersion
            reviewedPatientVersion = bundle.patient.__v
            if let content = note?.draft_content {
                noteComplaint = content.complaint ?? ""; noteHistory = content.history ?? ""
                noteExamination = content.examination ?? ""; noteAssessment = content.assessment ?? ""
                noteAdvice = content.advice ?? ""
                notePreviousHistory = content.previous_history ?? ""; noteTreatment = content.treatment ?? ""
                noteFollowUp = content.follow_up
                selectedDiagnoses = Set(content.diagnoses?.map(\.id) ?? [])
                medications = content.medications?.map { PrescriptionDrug(drug_id: $0.drug_id, dose: $0.dose, frequency: $0.frequency, duration: $0.duration, instructions: $0.instructions) } ?? []
            }
            hasLoadedDraft = true
        } else if remoteVersion != noteVersion || reviewedPatientVersion != bundle.patient.__v {
            recordChangedElsewhere = true
            errorMessage = "This note or patient record changed in another app. Your edits are kept here. Close and reopen the visit to review the hospital draft before signing."
        }
    }

    func startConsultation() async -> Bool {
        guard let encounterId = encounterId else { return false }
        isSubmitting = true
        errorMessage = nil
        do {
            let queue: [QueueEntry] = try await apiClient.execute(endpoint: QueueEndpoint())
            guard let entry = queue.first(where: { $0.encounter_id == encounterId }) else { throw APIError.invalidResponse }
            currentVersion = entry.__v
            if entry.status != "CONSULTATION" {
                let started: EncounterMutationResponse = try await apiClient.execute(endpoint: StartConsultEndpoint(encounterId: encounterId, v: currentVersion))
                if let v = started.__v {
                    currentVersion = v
                } else {
                    // Response carried no version: re-read it from the queue (same as the nurse flow).
                    let updated: [QueueEntry] = try await apiClient.execute(endpoint: QueueEndpoint())
                    if let refreshed = updated.first(where: { $0.encounter_id == encounterId }) {
                        currentVersion = refreshed.__v
                    }
                }
            }
            await fetchPatientDossier()
            isSubmitting = false
            return true
        } catch let error as APIError {
            handleAPIError(error)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isSubmitting = false
        return false
    }
    
    func orderLab(testId: String) async {
        guard let encounterId = encounterId else { return }
        guard !orderedTestIds.contains(testId), !labOrdersInFlight.contains(testId) else { return }
        labOrdersInFlight.insert(testId)
        defer { labOrdersInFlight.remove(testId) }
        do {
            struct LabResponse: Codable {}
            let _: LabResponse = try await apiClient.execute(endpoint: OrderLabEndpoint(encounterId: encounterId, testId: testId))
            // Refresh dossier to show new lab
            await fetchPatientDossier()
        } catch {
            self.errorMessage = "Failed to order lab: \(error.localizedDescription)"
        }
    }
    
    func amendConsultation() async -> Bool {
        guard !isSubmitting, !recordChangedElsewhere, let encounterId, let reviewedPatientVersion else { return false }
        isSubmitting = true
        errorMessage = nil
        do {
            let cData = ConsultationData(
                complaint: noteComplaint.isEmpty ? nil : noteComplaint,
                history: noteHistory.isEmpty ? nil : noteHistory,
                previous_history: notePreviousHistory.isEmpty ? nil : notePreviousHistory,
                examination: noteExamination.isEmpty ? nil : noteExamination,
                assessment: noteAssessment.isEmpty ? nil : noteAssessment,
                diagnosis_ids: Array(selectedDiagnoses),
                treatment: noteTreatment.isEmpty ? nil : noteTreatment,
                advice: noteAdvice.isEmpty ? nil : noteAdvice,
                medications: medications,
                follow_up: noteFollowUp
            )
            let response: EncounterMutationResponse = try await apiClient.execute(
                endpoint: AmendConsultEndpoint(encounterId: encounterId, v: noteVersion, patientVersion: reviewedPatientVersion, data: cData, reason: amendReason)
            )
            if let newV = response.__v {
                self.noteVersion = newV
            }
            consultationCompleted = true
            isSubmitting = false
            return true
        } catch let error as APIError {
            handleAPIError(error)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isSubmitting = false
        return false
    }

    func completeConsultation() async -> Bool {
        guard !isSubmitting, !recordChangedElsewhere else { return false }
        guard let encounterId = encounterId else { return false }
        guard let reviewedPatient = recordBundle?.patient, reviewedPatient.id == patientId,
              let reviewedPatientVersion else {
            errorMessage = "Load and review this patient's hospital record before signing."
            return false
        }
        isSubmitting = true
        errorMessage = nil
        do {
            let cData = ConsultationData(
                complaint: noteComplaint.isEmpty ? nil : noteComplaint,
                history: noteHistory.isEmpty ? nil : noteHistory,
                previous_history: notePreviousHistory.isEmpty ? nil : notePreviousHistory,
                examination: noteExamination.isEmpty ? nil : noteExamination,
                assessment: noteAssessment.isEmpty ? nil : noteAssessment,
                diagnosis_ids: Array(selectedDiagnoses),
                treatment: noteTreatment.isEmpty ? nil : noteTreatment,
                advice: noteAdvice.isEmpty ? nil : noteAdvice,
                medications: medications,
                follow_up: noteFollowUp
            )
            
            let response: EncounterMutationResponse = try await apiClient.execute(
                endpoint: CompleteConsultEndpoint(encounterId: encounterId, v: noteVersion, data: cData, patientVersion: reviewedPatientVersion)
            )
            if let newV = response.__v {
                self.noteVersion = newV
            }
            consultationCompleted = true
            isSubmitting = false
            return true
        } catch let error as APIError {
            handleAPIError(error)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isSubmitting = false
        return false
    }
    
    private func handleAPIError(_ error: APIError) {
        switch error {
        case .apiError(_, let response):
            if response.error.code == "STALE_STATE" {
                self.errorMessage = "State is stale. The queue has been updated elsewhere. Please go back and refresh."
            } else {
                self.errorMessage = response.error.message
            }
        case .httpError(let statusCode, _):
            self.errorMessage = "HTTP Error \(statusCode)"
        default:
            self.errorMessage = error.localizedDescription
        }
    }
}

struct CataloguesResponse: Codable {
    struct Drug: Codable, Identifiable {
        let id: String
        let name: String
        let strength: String
        let form: String
        let route: String
    }
    struct Diagnosis: Codable, Identifiable {
        let id: String
        let name: String
    }
    struct Test: Codable, Identifiable {
        let id: String
        let name: String
        let code: String
    }
    let drugs: [Drug]
    let diagnoses: [Diagnosis]
    let tests: [Test]
}

struct CataloguesEndpoint: APIEndpoint {
    var path: String { "/api/v1/opd/catalogues" }
    var method: HTTPMethod { .get }
}

struct OrderLabEndpoint: APIEndpoint {
    let encounterId: String
    let testId: String
    var path: String { "/api/v1/opd/encounters/\(encounterId)/labs" }
    var method: HTTPMethod { .post }
    var body: Data? { try? JSONSerialization.data(withJSONObject: ["test_id": testId]) }
}
