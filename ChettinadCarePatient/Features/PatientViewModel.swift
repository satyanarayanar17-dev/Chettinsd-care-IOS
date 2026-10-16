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
    @Published var isSubmitting = false
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    
    let apiClient: APIClient
    init(apiClient: APIClient = APIClient()) { self.apiClient = apiClient }
    private var patientId: String?
    private var recordsRevision = 0
    private var slotsRevision = 0
    
    func fetchRecords(silent: Bool = false) async {
        recordsRevision += 1
        let revision = recordsRevision
        if !silent { isLoading = true; errorMessage = nil }
        defer { if revision == recordsRevision { isLoading = false } }
        do {
            let session: UserSession = try await apiClient.execute(endpoint: OPDSessionEndpoint())
            guard let patientId = session.patient_id else {
                self.errorMessage = "Patient ID not found in session."
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
            
            async let recordRequest: RecordBundle = apiClient.execute(endpoint: PatientRecordEndpoint(patientId: patientId))
            async let appointmentsRequest: [Appointment] = apiClient.execute(endpoint: PatientAppointmentsEndpoint(patientId: patientId))
            async let directoryRequest: OPDDirectory = apiClient.execute(endpoint: DirectoryEndpoint())
            async let selfRecordsRequest: [PatientSelfRecord] = apiClient.execute(endpoint: PatientSelfRecordsEndpoint(patientId: patientId))
            async let documentsRequest: [PatientDocument] = apiClient.execute(endpoint: PatientDocumentsEndpoint(patientId: patientId))
            async let careTasksRequest: [CarePlanOccurrenceDTO] = apiClient.execute(endpoint: GetTodayAdherenceEndpoint(patientId: patientId))
            // Publish one complete snapshot so a failed refresh cannot mix old and new care data.
            let loaded = try await (recordRequest, appointmentsRequest, directoryRequest, selfRecordsRequest, documentsRequest, careTasksRequest)
            guard !Task.isCancelled, revision == recordsRevision else { return }
            guard loaded.0.patient.id == patientId,
                  loaded.1.allSatisfy({ $0.patient_id == nil || $0.patient_id == patientId }),
                  loaded.4.allSatisfy({ $0.patient_id == patientId }) else { throw APIError.invalidResponse }
            self.recordBundle = loaded.0
            self.appointments = loaded.1
            self.directory = loaded.2
            self.selfRecords = loaded.3
            self.documents = loaded.4
            self.todayCareTasks = loaded.5
        } catch is CancellationError {
            return
        } catch {
            guard !Task.isCancelled, revision == recordsRevision else { return }
            self.errorMessage = error.localizedDescription
        }
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
        slotsRevision += 1
        let revision = slotsRevision
        slots = []
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Kolkata")
        formatter.dateFormat = "yyyy-MM-dd"
        do {
            let loaded: [AppointmentSlot] = try await apiClient.execute(endpoint: AppointmentSlotsEndpoint(doctorId: doctorId, date: formatter.string(from: date)))
            guard !Task.isCancelled, revision == slotsRevision else { return }
            slots = loaded
        } catch {
            guard !Task.isCancelled, revision == slotsRevision else { return }
            slots = []; errorMessage = error.localizedDescription
        }
    }

    func book(doctorId: String, scheduledAt: String, reason: String) async -> Bool {
        guard !isSubmitting else { return false };isSubmitting = true;recordsRevision += 1;isLoading = false;defer { isSubmitting = false };errorMessage = nil
        errorMessage = nil
        do {
            let _: Appointment = try await apiClient.execute(endpoint: BookAppointmentEndpoint(doctorId: doctorId, scheduledAt: scheduledAt, reason: reason))
            await fetchRecords()
            return true
        } catch { errorMessage = error.localizedDescription; return false }
    }

    func uploadDocument(fileURL: URL, title: String, documentType: String, clinicalDate: String, appointmentId: String?, note: String?) async -> Bool {
        guard !isSubmitting else { return false };isSubmitting = true;recordsRevision += 1;isLoading = false;defer { isSubmitting = false };errorMessage = nil
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
        guard !isSubmitting else { return false };isSubmitting = true;recordsRevision += 1;isLoading = false;defer { isSubmitting = false };errorMessage = nil
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
import Foundation
extension PatientViewModel {
    func cancelAppointment(_ id: String, version: Int) async -> Bool {
        guard !isSubmitting else { return false };isSubmitting = true;recordsRevision += 1;isLoading = false;defer { isSubmitting = false };errorMessage = nil
        do {
            let endpoint = CancelAppointmentEndpoint(appointmentId: id, version: version)
            struct AnyResponse: Codable {}
            let _: AnyResponse = try await apiClient.execute(endpoint: endpoint)
            await fetchRecords()
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
}
struct CancelAppointmentEndpoint: APIEndpoint {
    struct AnyResponse: Codable {}
    typealias Response = AnyResponse
    let appointmentId: String
    let version: Int
    var path: String { "/api/v1/opd/appointments/\(appointmentId)/cancel" }
    var method: HTTPMethod { .post }
    var requiresAuth: Bool { true }
    var body: Data? {
        let payload = ["__v": version]
        return try? JSONEncoder().encode(payload)
    }
}
extension PatientViewModel {
    func updateProfile(email: String, address: String, city: String, state: String, pinCode: String, emergencyContact: String, version: Int) async -> Bool {
        guard !isSubmitting else { return false };isSubmitting = true;recordsRevision += 1;isLoading = false;defer { isSubmitting = false };errorMessage = nil
        guard let id = recordBundle?.patient.id else { return false }
        do {
            let payload = UpdateProfilePayload(email: email, address: address, city: city, state: state, pin_code: pinCode, emergency_contact: emergencyContact, __v: version)
            let endpoint = UpdateProfileEndpoint(patientId: id, payload: payload)
            struct AnyResponse: Codable {}
            let _: AnyResponse = try await apiClient.execute(endpoint: endpoint)
            await fetchRecords()
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
}
struct UpdateProfilePayload: Codable {
    let email: String?
    let address: String?
    let city: String?
    let state: String?
    let pin_code: String?
    let emergency_contact: String?
    let __v: Int
}
struct UpdateProfileEndpoint: APIEndpoint {
    struct AnyResponse: Codable {}
    typealias Response = AnyResponse
    let patientId: String
    let payload: UpdateProfilePayload
    var path: String { "/api/v1/opd/patients/\(patientId)" }
    var method: HTTPMethod { .patch }
    var requiresAuth: Bool { true }
    var body: Data? {
        guard let encoded = try? JSONEncoder().encode(payload),
              var data = try? JSONSerialization.jsonObject(with: encoded) as? [String: Any] else { return nil }
        data.removeValue(forKey: "__v")
        return try? JSONSerialization.data(withJSONObject: ["data": data, "__v": payload.__v])
    }
}
