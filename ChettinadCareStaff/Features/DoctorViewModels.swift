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
    var path: String { "/api/v1/opd/encounters/\(encounterId)/complete" }
    var method: HTTPMethod { .post }
    var body: Data? { try? JSONSerialization.data(withJSONObject: ["__v": v]) }
}

struct SubmitNoteEndpoint: APIEndpoint {
    let encounterId: String
    let draftContent: NoteSubmission
    var path: String { "/api/v1/opd/encounters/\(encounterId)/notes" }
    var method: HTTPMethod { .post }
    var body: Data? { try? JSONEncoder().encode(draftContent) }
}

struct NoteSubmission: Codable {
    let draft_content: NoteSubmissionContent
    let status: String
}

struct NoteSubmissionContent: Codable {
    let complaint: String
    let examination: String
    let assessment: String
    let advice: String
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
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    
    let apiClient = APIClient()
    
    func fetchQueue() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetchedQueue: [QueueEntry] = try await apiClient.execute(endpoint: QueueEndpoint())
            self.queue = fetchedQueue
        } catch {
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
    let encounterId: String
    let patientId: String
    
    // Consultation note fields
    @Published var noteComplaint = ""
    @Published var noteExamination = ""
    @Published var noteAssessment = ""
    @Published var noteAdvice = ""
    @Published var isSubmitting = false
    
    let apiClient = APIClient()
    
    init(encounterId: String, patientId: String, initialVersion: Int) {
        self.encounterId = encounterId
        self.patientId = patientId
        self.currentVersion = initialVersion
    }
    
    func fetchPatientDossier() async {
        isLoading = true
        errorMessage = nil
        do {
            let bundle: RecordBundle = try await apiClient.execute(
                endpoint: PatientRecordEndpoint(patientId: patientId)
            )
            self.recordBundle = bundle
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func startConsultation() async -> Bool {
        isSubmitting = true
        errorMessage = nil
        do {
            let response: EncounterMutationResponse = try await apiClient.execute(
                endpoint: StartConsultEndpoint(encounterId: encounterId, v: currentVersion)
            )
            if let newV = response.__v {
                self.currentVersion = newV
            }
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
        isSubmitting = true
        errorMessage = nil
        do {
            // 1. Submit Note
            let submission = NoteSubmission(
                draft_content: NoteSubmissionContent(
                    complaint: noteComplaint,
                    examination: noteExamination,
                    assessment: noteAssessment,
                    advice: noteAdvice
                ),
                status: "FINALIZED"
            )
            let _: NoteResponse = try await apiClient.execute(
                endpoint: SubmitNoteEndpoint(encounterId: encounterId, draftContent: submission)
            )
            
            // 2. Complete Encounter
            let response: EncounterMutationResponse = try await apiClient.execute(
                endpoint: CompleteConsultEndpoint(encounterId: encounterId, v: currentVersion)
            )
            if let newV = response.__v {
                self.currentVersion = newV
            }
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
