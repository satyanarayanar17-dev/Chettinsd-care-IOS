import SwiftUI
import ChettinadCore

@MainActor
class PatientViewModel: ObservableObject {
    @Published var recordBundle: RecordBundle?
    @Published var appointments: [Appointment] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    let apiClient = APIClient()
    
    func fetchRecords() async {
        isLoading = true
        errorMessage = nil
        do {
            let session: UserSession = try await apiClient.execute(endpoint: OPDSessionEndpoint())
            guard let patientId = session.patient_id else {
                self.errorMessage = "Patient ID not found in session."
                self.isLoading = false
                return
            }
            
            struct PatientRecordEndpoint: APIEndpoint {
                let patientId: String
                var path: String { "/api/v1/opd/patients/\(patientId)/record" }
                var method: HTTPMethod { .get }
            }
            
            struct PatientAppointmentsEndpoint: APIEndpoint {
                let patientId: String
                var path: String { "/api/v1/opd/appointments?patient_id=\(patientId)" }
                var method: HTTPMethod { .get }
            }
            
            let bundle: RecordBundle = try await apiClient.execute(endpoint: PatientRecordEndpoint(patientId: patientId))
            self.recordBundle = bundle
            
            let apts: [Appointment] = try await apiClient.execute(endpoint: PatientAppointmentsEndpoint(patientId: patientId))
            self.appointments = apts
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
