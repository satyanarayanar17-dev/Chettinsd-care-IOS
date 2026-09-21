import SwiftUI
import ChettinadCore

struct DirectoryResponse: Codable {
    struct Doctor: Codable, Identifiable {
        let id: String
        let name: String
        let department: String
    }
    let doctors: [Doctor]
}

struct PatientSearchResponse: Codable, Identifiable {
    let id: String
    let name: String
    let mrn: String?
    let phone: String
}

struct Slot: Codable {
    let scheduled_at: String
}

struct BookAppointmentPayload: Codable {
    let patient_id: String
    let doctor_id: String
    let scheduled_at: String
    let reason: String
}

struct BookAppointmentEndpoint: APIEndpoint {
    let payload: BookAppointmentPayload
    var path: String { "/api/v1/opd/appointments" }
    var method: HTTPMethod { .post }
    var body: Data? { try? JSONEncoder().encode(payload) }
}

struct AdminAppointmentsEndpoint: APIEndpoint {
    let date: String
    var path: String { "/api/v1/opd/appointments?date=\(date)" }
    var method: HTTPMethod { .get }
}

struct AdminCheckInEndpoint: APIEndpoint {
    let appointmentId: String
    var path: String { "/api/v1/opd/appointments/\(appointmentId)/check-in" }
    var method: HTTPMethod { .post }
    var body: Data? { try? JSONSerialization.data(withJSONObject: ["identity_verified": true]) }
}

@MainActor
class AdminDashboardViewModel: ObservableObject {
    @Published var appointments: [Appointment] = []
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    
    let apiClient = APIClient()
    
    func fetchAppointments() async {
        isLoading = true
        errorMessage = nil
        do {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
            let dateString = formatter.string(from: Date())
            
            let fetched: [Appointment] = try await apiClient.execute(endpoint: AdminAppointmentsEndpoint(date: dateString))
            self.appointments = fetched
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func checkIn(appointmentId: String) async {
        do {
            let _: QueueEntry = try await apiClient.execute(endpoint: AdminCheckInEndpoint(appointmentId: appointmentId))
            await fetchAppointments()
        } catch {
            self.errorMessage = "Check-in failed: \(error.localizedDescription)"
        }
    }
}

struct PatientSearchEndpoint: APIEndpoint {
    let query: String
    var path: String { "/api/v1/opd/patients?search=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)" }
    var method: HTTPMethod { .get }
}

struct DirectoryEndpoint: APIEndpoint {
    var path: String { "/api/v1/opd/directory" }
    var method: HTTPMethod { .get }
}

struct SlotsEndpoint: APIEndpoint {
    let doctorId: String
    let date: String
    var path: String { "/api/v1/opd/slots?doctor_id=\(doctorId)&date=\(date)" }
    var method: HTTPMethod { .get }
}

@MainActor
class BookAppointmentViewModel: ObservableObject {
    @Published var searchQuery = ""
    @Published var searchResults: [PatientSearchResponse] = []
    @Published var selectedPatientId: String? = nil
    
    @Published var doctors: [DirectoryResponse.Doctor] = []
    @Published var selectedDoctorId: String? = nil
    
    @Published var selectedDate = Date()
    @Published var availableSlots: [Slot] = []
    @Published var selectedSlot: String? = nil
    
    @Published var reason = "Routine Consultation"
    
    @Published var isSearching = false
    @Published var isSubmitting = false
    @Published var errorMessage: String? = nil
    
    let apiClient = APIClient()
    
    func searchPatients() async {
        guard searchQuery.count > 2 else { return }
        isSearching = true
        do {
            let results: [PatientSearchResponse] = try await apiClient.execute(endpoint: PatientSearchEndpoint(query: searchQuery))
            self.searchResults = results
        } catch {
            self.errorMessage = "Search failed: \(error.localizedDescription)"
        }
        isSearching = false
    }
    
    func fetchDoctors() async {
        do {
            let directory: DirectoryResponse = try await apiClient.execute(endpoint: DirectoryEndpoint())
            self.doctors = directory.doctors
        } catch {
            print("Failed to fetch doctors: \(error)")
        }
    }
    
    func fetchSlots() async {
        guard let doctorId = selectedDoctorId else { return }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        let dateString = formatter.string(from: selectedDate)
        
        do {
            let slots: [Slot] = try await apiClient.execute(endpoint: SlotsEndpoint(doctorId: doctorId, date: dateString))
            self.availableSlots = slots
        } catch {
            print("Failed to fetch slots: \(error)")
            self.availableSlots = []
        }
    }
    
    func bookAppointment() async -> Bool {
        guard let pId = selectedPatientId, let dId = selectedDoctorId, let slot = selectedSlot else { return false }
        isSubmitting = true
        errorMessage = nil
        do {
            let payload = BookAppointmentPayload(patient_id: pId, doctor_id: dId, scheduled_at: slot, reason: reason)
            struct BookResponse: Codable {} // Don't care about response body
            let _: BookResponse = try await apiClient.execute(endpoint: BookAppointmentEndpoint(payload: payload))
            isSubmitting = false
            return true
        } catch {
            self.errorMessage = "Booking failed: \(error.localizedDescription)"
            isSubmitting = false
            return false
        }
    }
}

struct StaffMember: Codable, Identifiable {
    let id: String
    let name: String
    let role: String
    let department: String?
    let is_active: Int
}

struct StaffListEndpoint: APIEndpoint {
    var path: String { "/api/v1/opd/staff" }
    var method: HTTPMethod { .get }
}

@MainActor
class StaffManagementViewModel: ObservableObject {
    @Published var staffMembers: [StaffMember] = []
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    
    let apiClient = APIClient()
    
    func fetchStaff() async {
        isLoading = true
        errorMessage = nil
        do {
            let list: [StaffMember] = try await apiClient.execute(endpoint: StaffListEndpoint())
            self.staffMembers = list
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
