import SwiftUI
import ChettinadCore

@MainActor
class CarePlanViewModel: ObservableObject {
    @Published var tasks: [CarePlanOccurrenceDTO] = []
    @Published var timeline: [AdherenceResponseDTO] = []
    @Published var selfRecords: [PatientSelfRecord] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    let apiClient = APIClient()
    
    private var cachedPatientId: String? = nil
    
    private func getPatientId() async throws -> String {
        if let id = cachedPatientId { return id }
        let session: UserSession = try await apiClient.execute(endpoint: OPDSessionEndpoint())
        guard let patientId = session.patient_id else {
            throw NSError(domain: "ChettinadCare", code: 401, userInfo: [NSLocalizedDescriptionKey: "Patient ID not found in session."])
        }
        self.cachedPatientId = patientId
        return patientId
    }
    
    func fetchTodayCarePlan() async {
        isLoading = true
        errorMessage = nil
        do {
            let patientId = try await getPatientId()
            let endpoint = GetTodayAdherenceEndpoint(patientId: patientId)
            self.tasks = try await apiClient.execute(endpoint: endpoint)
            
            // Schedule local reminders
            _ = try? await NotificationManager.shared.requestAuthorization()
            await NotificationManager.shared.scheduleCarePlanReminders(tasks: self.tasks)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func fetchTimeline() async {
        do {
            let patientId = try await getPatientId()
            let endpoint = GetTimelineEndpoint(patientId: patientId)
            self.timeline = try await apiClient.execute(endpoint: endpoint)
            self.selfRecords = try await apiClient.execute(endpoint: PatientSelfRecordsEndpoint(patientId: patientId))
        } catch {
            errorMessage = "Timeline could not be loaded. Please try again."
        }
    }

    func addSelfRecord(_ payload: PatientSelfRecordPayload) async -> Bool {
        errorMessage = nil
        do {
            let patientId = try await getPatientId()
            let endpoint = try CreatePatientSelfRecordEndpoint(patientId: patientId, payload: payload)
            let created: PatientSelfRecord = try await apiClient.execute(endpoint: endpoint)
            selfRecords.insert(created, at: 0)
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }
    
    func recordAdherence(resourceId: String, payload: RecordAdherencePayload) async -> Bool {
        errorMessage = nil
        do {
            let endpoint = RecordAdherenceEndpoint(resourceId: resourceId, payload: payload)
            // Just hit the endpoint, ignoring return if we don't parse it
            
            let _: CarePlanOccurrenceDTO = try await apiClient.execute(endpoint: endpoint)
            await fetchTodayCarePlan()
            return true
        } catch let error as APIError {
            if case .apiError(409, let response) = error, response.error.code == "STALE_STATE" {
                self.errorMessage = "This task changed on another device. The latest state has been reloaded."
                await fetchTodayCarePlan()
                await fetchTimeline()
            } else {
                self.errorMessage = "The Care Plan could not be updated. Please try again."
            }
            return false
        } catch {
            self.errorMessage = "The Care Plan could not be updated. Please try again."
            return false
        }
    }
}

struct PatientSelfRecordPayload: Encodable, Sendable {
    let record_type: String
    let timing_context: String?
    let numeric_value: Double?
    let secondary_numeric_value: Double?
    let unit: String?
    let activity_name: String?
    let duration_minutes: Int?
    let observed_at: String
    let patient_note: String?
}
