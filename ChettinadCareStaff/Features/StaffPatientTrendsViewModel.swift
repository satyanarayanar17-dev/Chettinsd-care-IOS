import Foundation
import ChettinadCore

@MainActor
class StaffPatientTrendsViewModel: ObservableObject {
    @Published var timeline: [AdherenceEvent] = []
    @Published var selfRecords: [PatientSelfRecord] = []
    @Published var isLoading = true
    @Published var trendsError: String?
    
    let patientId: String
    private let apiClient = APIClient()
    
    init(patientId: String) {
        self.patientId = patientId
    }
    
    func fetchTimeline() async {
        isLoading = true
        trendsError = nil
        do {
            async let timelineTask: [AdherenceEvent] = try await apiClient.execute(endpoint: GetTimelineEndpoint(patientId: patientId))
            async let selfRecordsTask: [PatientSelfRecord] = try await apiClient.execute(endpoint: PatientSelfRecordsEndpoint(patientId: patientId))
            
            let (fetchedTimeline, fetchedSelfRecords) = try await (timelineTask, selfRecordsTask)
            self.timeline = fetchedTimeline
            self.selfRecords = fetchedSelfRecords
        } catch {
            trendsError = error.localizedDescription
        }
        isLoading = false
    }
}
