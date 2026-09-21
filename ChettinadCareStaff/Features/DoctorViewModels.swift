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
    var path: String { "/api/v1/opd/encounters/\(encounterId)/complete" }
    var method: HTTPMethod { .post }
    var body: Data? {
        let payload = CompletePayload(__v: v, data: data)
        return try? JSONEncoder().encode(payload)
    }
}

struct CompletePayload: Codable {
    let __v: Int
    let data: ConsultationData
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
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    
    let apiClient = APIClient()
    
    func fetchQueue() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetchedQueue: [QueueEntry] = try await apiClient.execute(endpoint: QueueEndpoint())
            self.queue = fetchedQueue.filter { $0.status == "WAITING_DOCTOR" || $0.status == "DOCTOR_READY" || $0.status == "CONSULTATION" }
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
    
    // Catalogues
    @Published var catalogues: CataloguesResponse?
    @Published var selectedDiagnoses: Set<String> = []
    @Published var medications: [PrescriptionDrug] = []
    
    let apiClient = APIClient()
    
    init(encounterId: String, patientId: String, initialVersion: Int) {
        self.encounterId = encounterId
        self.patientId = patientId
        self.currentVersion = initialVersion
    }
    
    func fetchCatalogues() async {
        do {
            let cat: CataloguesResponse = try await apiClient.execute(endpoint: CataloguesEndpoint())
            self.catalogues = cat
        } catch {
            print("Failed to fetch catalogues: \(error)")
        }
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
    
    func orderLab(testId: String) async {
        do {
            struct LabResponse: Codable {}
            let _: LabResponse = try await apiClient.execute(endpoint: OrderLabEndpoint(encounterId: encounterId, testId: testId))
            // Refresh dossier to show new lab
            await fetchPatientDossier()
        } catch {
            self.errorMessage = "Failed to order lab: \(error.localizedDescription)"
        }
    }
    
    func completeConsultation() async -> Bool {
        isSubmitting = true
        errorMessage = nil
        do {
            let cData = ConsultationData(
                complaint: noteComplaint.isEmpty ? nil : noteComplaint,
                history: nil,
                previous_history: nil,
                examination: noteExamination.isEmpty ? nil : noteExamination,
                assessment: noteAssessment.isEmpty ? nil : noteAssessment,
                diagnosis_ids: Array(selectedDiagnoses),
                treatment: nil,
                advice: noteAdvice.isEmpty ? nil : noteAdvice,
                medications: medications
            )
            
            let response: EncounterMutationResponse = try await apiClient.execute(
                endpoint: CompleteConsultEndpoint(encounterId: encounterId, v: currentVersion, data: cData)
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
