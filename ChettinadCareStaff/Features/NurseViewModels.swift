import SwiftUI
import ChettinadCore

// MARK: - Endpoints

struct StartTriageEndpoint: APIEndpoint {
    let encounterId: String
    let v: Int
    var path: String { "/api/v1/opd/encounters/\(encounterId)/start-triage" }
    var method: HTTPMethod { .post }
    var body: Data? { try? JSONSerialization.data(withJSONObject: ["__v": v]) }
}

struct SubmitTriageEndpoint: APIEndpoint {
    struct Payload: Codable {
        let __v: Int
        let data: TriageData
    }
    
    let encounterId: String
    let v: Int
    let data: TriageData
    var path: String { "/api/v1/opd/encounters/\(encounterId)/triage" }
    var method: HTTPMethod { .post }
    var body: Data? { try? JSONEncoder().encode(Payload(__v: v, data: data)) }
}

// MARK: - Nurse Triage ViewModel

@MainActor
class NurseTriageViewModel: ObservableObject {
    @Published var queue: [QueueEntry] = []
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    
    let apiClient = APIClient()
    
    func fetchQueue() async {
        isLoading = true
        errorMessage = nil
        do {
            let fetchedQueue: [QueueEntry] = try await apiClient.execute(endpoint: QueueEndpoint())
            self.queue = fetchedQueue.filter { $0.status == "WAITING" || $0.status == "TRIAGE" }
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

// MARK: - Triage Form ViewModel

@MainActor
class TriageFormViewModel: ObservableObject {
    @Published var currentVersion: Int
    let encounterId: String
    
    @Published var temperature: String = ""
    @Published var systolic: String = ""
    @Published var diastolic: String = ""
    @Published var pulse: String = ""
    @Published var spo2: String = ""
    @Published var weight: String = ""
    @Published var height: String = ""
    @Published var pain: String = ""
    @Published var notes: String = ""
    @Published var priority: Int = 0
    @Published var complaint: String = ""
    
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var errorMessage: String? = nil
    
    let apiClient = APIClient()
    
    init(encounterId: String, initialVersion: Int) {
        self.encounterId = encounterId
        self.currentVersion = initialVersion
    }
    
    func startTriage() async -> Bool {
        isLoading = true
        errorMessage = nil
        do {
            let queue: [QueueEntry] = try await apiClient.execute(endpoint: QueueEndpoint())
            guard let entry = queue.first(where: { $0.encounter_id == encounterId }) else { throw APIError.invalidResponse }
            currentVersion = entry.__v
            if entry.status == "WAITING" {
                let _: EncounterMutationResponse = try await apiClient.execute(endpoint: StartTriageEndpoint(encounterId: encounterId, v: currentVersion))
                let updated: [QueueEntry] = try await apiClient.execute(endpoint: QueueEndpoint())
                guard let refreshed = updated.first(where: { $0.encounter_id == encounterId }) else { throw APIError.invalidResponse }
                currentVersion = refreshed.__v
            }
            isLoading = false
            return true
        } catch let error as APIError {
            handleAPIError(error)
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
        return false
    }
    
    func submitTriage() async -> Bool {
        isSubmitting = true
        errorMessage = nil
        
        let tData = TriageData(
            temperature: Double(temperature),
            systolic: Int(systolic),
            diastolic: Int(diastolic),
            pulse: Int(pulse),
            spo2: Int(spo2),
            weight: Double(weight),
            height: Double(height),
            complaint: complaint.isEmpty ? nil : complaint,
            allergies: nil,
            pain: Int(pain),
            notes: notes,
            priority: priority,
            bmi: nil
        )
        
        do {
            let response: EncounterMutationResponse = try await apiClient.execute(
                endpoint: SubmitTriageEndpoint(encounterId: encounterId, v: currentVersion, data: tData)
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
