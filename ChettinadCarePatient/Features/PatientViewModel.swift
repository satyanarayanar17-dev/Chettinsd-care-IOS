import SwiftUI
import ChettinadCore

@MainActor
class PatientViewModel: ObservableObject {
    @Published var recordBundle: RecordBundle?
    @Published var appointments: [Appointment] = []
    @Published var directory: OPDDirectory?
    @Published var slots: [AppointmentSlot] = []
    @Published var selfRecords: [PatientSelfRecord] = []
    @Published var documents: [PatientDocument] = []
    @Published var todayCareTasks: [CarePlanOccurrenceDTO] = []
    @Published var timeline: [AdherenceResponseDTO] = []
    @Published var trendsError: String? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    let apiClient = APIClient()
    private var patientId: String?
    
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
            self.patientId = patientId
            
            struct PatientRecordEndpoint: APIEndpoint {
                let patientId: String
                var path: String { "/api/v1/opd/patients/\(patientId)/record" }
                var method: HTTPMethod { .get }
            }
            
            struct PatientAppointmentsEndpoint: APIEndpoint {
                let patientId: String
                var path: String { "/api/v1/opd/appointments" }
                var method: HTTPMethod { .get }
            }
            
            let bundle: RecordBundle = try await apiClient.execute(endpoint: PatientRecordEndpoint(patientId: patientId))
            self.recordBundle = bundle
            
            let apts: [Appointment] = try await apiClient.execute(endpoint: PatientAppointmentsEndpoint(patientId: patientId))
            self.appointments = apts
            async let directoryRequest: OPDDirectory = apiClient.execute(endpoint: DirectoryEndpoint())
            async let selfRecordsRequest: [PatientSelfRecord] = apiClient.execute(endpoint: PatientSelfRecordsEndpoint(patientId: patientId))
            async let documentsRequest: [PatientDocument] = apiClient.execute(endpoint: PatientDocumentsEndpoint(patientId: patientId))
            async let careTasksRequest: [CarePlanOccurrenceDTO] = apiClient.execute(endpoint: GetTodayAdherenceEndpoint(patientId: patientId))
            self.directory = try await directoryRequest
            self.selfRecords = try await selfRecordsRequest
            self.documents = try await documentsRequest
            self.todayCareTasks = try await careTasksRequest
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func fetchTimeline() async {
        do {
            let id: String
            if let patientId {
                id = patientId
            } else {
                let session: UserSession = try await apiClient.execute(endpoint: OPDSessionEndpoint())
                guard let pid = session.patient_id else {
                    trendsError = "Patient ID not found in session."
                    return
                }
                self.patientId = pid
                id = pid
            }
            timeline = try await apiClient.execute(endpoint: GetTimelineEndpoint(patientId: id))
            selfRecords = try await apiClient.execute(endpoint: PatientSelfRecordsEndpoint(patientId: id))
            trendsError = nil
        } catch {
            trendsError = "Trends could not be loaded. Please try again."
        }
    }

    func fetchSlots(doctorId: String, date: Date) async {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Kolkata")
        formatter.dateFormat = "yyyy-MM-dd"
        do { slots = try await apiClient.execute(endpoint: AppointmentSlotsEndpoint(doctorId: doctorId, date: formatter.string(from: date))) }
        catch { slots = []; errorMessage = error.localizedDescription }
    }

    func book(doctorId: String, scheduledAt: String, reason: String) async -> Bool {
        errorMessage = nil
        do {
            let _: Appointment = try await apiClient.execute(endpoint: BookAppointmentEndpoint(doctorId: doctorId, scheduledAt: scheduledAt, reason: reason))
            await fetchRecords()
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    func uploadDocument(fileURL: URL, title: String, documentType: String, clinicalDate: String, appointmentId: String?, note: String?) async -> Bool {
        guard let patientId else {
            errorMessage = "Your records are still loading. Please try again."
            return false
        }
        errorMessage = nil
        do {
            let document = try await apiClient.uploadPatientDocument(patientId: patientId, fileURL: fileURL, title: title, documentType: documentType, clinicalDate: clinicalDate, appointmentId: appointmentId, note: note)
            documents.insert(document, at: 0)
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    func linkDocument(_ document: PatientDocument, to appointmentId: String?) async -> Bool {
        guard let patientId else {
            errorMessage = "Your records are still loading. Please try again."
            return false
        }
        errorMessage = nil
        do {
            let updated: PatientDocument = try await apiClient.execute(endpoint: LinkPatientDocumentAppointmentEndpoint(patientId: patientId, documentId: document.id, appointmentId: appointmentId))
            if let index = documents.firstIndex(where: { $0.id == document.id }) { documents[index] = updated }
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }
}
