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
    private var recordsRevision = 0
    
    func fetchRecords(silent: Bool = false) async {
        recordsRevision += 1
        let revision = recordsRevision
        if !silent { isLoading = true; errorMessage = nil }
        defer { if revision == recordsRevision { isLoading = false } }
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
            let apts: [Appointment] = try await apiClient.execute(endpoint: PatientAppointmentsEndpoint(patientId: patientId))
            async let directoryRequest: OPDDirectory = apiClient.execute(endpoint: DirectoryEndpoint())
            async let selfRecordsRequest: [PatientSelfRecord] = apiClient.execute(endpoint: PatientSelfRecordsEndpoint(patientId: patientId))
            async let documentsRequest: [PatientDocument] = apiClient.execute(endpoint: PatientDocumentsEndpoint(patientId: patientId))
            async let careTasksRequest: [CarePlanOccurrenceDTO] = apiClient.execute(endpoint: GetTodayAdherenceEndpoint(patientId: patientId))
            let (directory, selfRecords, documents, tasks) = try await (directoryRequest, selfRecordsRequest, documentsRequest, careTasksRequest)
            try Task.checkCancellation()
            guard revision == recordsRevision else { return }
            self.recordBundle = bundle; self.appointments = apts
            self.directory = directory; self.selfRecords = selfRecords
            self.documents = documents; self.todayCareTasks = tasks
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
import Foundation
extension PatientViewModel {
    func cancelAppointment(_ id: String, version: Int) async -> Bool {
        do {
            let endpoint = CancelAppointmentEndpoint(appointmentId: id, version: version)
            struct AnyResponse: Codable {}
            let _: AnyResponse = try await apiClient.execute(endpoint: endpoint)
            await fetchRecords()
            return true
        } catch {
            DispatchQueue.main.async { self.errorMessage = "Failed to cancel appointment." }
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
        guard let id = recordBundle?.patient.id else { return false }
        do {
            let payload = UpdateProfilePayload(email: email, address: address.isEmpty ? nil : address, city: city.isEmpty ? nil : city, state: state.isEmpty ? nil : state, pin_code: pinCode.isEmpty ? nil : pinCode, emergency_contact: emergencyContact.isEmpty ? nil : emergencyContact, __v: version)
            let endpoint = UpdateProfileEndpoint(patientId: id, payload: payload)
            struct AnyResponse: Codable {}
            let _: AnyResponse = try await apiClient.execute(endpoint: endpoint)
            await fetchRecords()
            return true
        } catch {
            DispatchQueue.main.async { self.errorMessage = "Failed to update profile." }
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
        struct Changes: Encodable {
            let email: String?; let address: String?; let city: String?; let state: String?
            let pin_code: String?; let emergency_contact: String?
        }
        struct Envelope: Encodable { let __v: Int; let data: Changes }
        return try? JSONEncoder().encode(Envelope(__v: payload.__v, data: Changes(
            email: payload.email, address: payload.address, city: payload.city, state: payload.state,
            pin_code: payload.pin_code, emergency_contact: payload.emergency_contact)))
    }
}
