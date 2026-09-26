import SwiftUI
import ChettinadCore

struct DirectoryResponse: Codable {
    struct Doctor: Codable, Identifiable {
        let id: String
        let name: String
        let department: String?
    }
    struct Department: Codable, Identifiable {
        let id: String
        let name: String
    }
    let departments: [Department]
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
    var path: String { "/api/v1/opd/appointments" }
    var queryItems: [URLQueryItem]? { [URLQueryItem(name: "date", value: date)] }
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
    
    func fetchAppointments(for date: Date = Date()) async {
        isLoading = true
        errorMessage = nil
        do {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
            formatter.timeZone = TimeZone(identifier: "Asia/Kolkata")
            let dateString = formatter.string(from: date)
            
            let fetched: [Appointment] = try await apiClient.execute(endpoint: AdminAppointmentsEndpoint(date: dateString))
            self.appointments = fetched
        } catch {
            if (error as NSError).domain == NSURLErrorDomain && (error as NSError).code == NSURLErrorCancelled { return }
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    
    func confirmAppointment(appointmentId: String) async {
        do {
            struct AnyResponse: Codable {}
            let _: AnyResponse = try await apiClient.execute(endpoint: AdminConfirmEndpoint(appointmentId: appointmentId))
            await fetchAppointments(for: selectedDate)
        } catch {
            self.errorMessage = "Confirm failed: \(error.localizedDescription)"
        }
    }

    func checkIn(appointmentId: String) async {
        do {
            let _: EncounterMutationResponse = try await apiClient.execute(endpoint: AdminCheckInEndpoint(appointmentId: appointmentId))
            await fetchAppointments()
        } catch {
            self.errorMessage = "Check-in failed: \(error.localizedDescription)"
        }
    }
}

struct PatientSearchEndpoint: APIEndpoint {
    let query: String
    var path: String { "/api/v1/opd/patients" }
    var queryItems: [URLQueryItem]? { [URLQueryItem(name: "search", value: query)] }
    var method: HTTPMethod { .get }
}

struct DirectoryEndpoint: APIEndpoint {
    var path: String { "/api/v1/opd/directory" }
    var method: HTTPMethod { .get }
}

struct SlotsEndpoint: APIEndpoint {
    let doctorId: String
    let date: String
    var path: String { "/api/v1/opd/slots" }
    var queryItems: [URLQueryItem]? { [URLQueryItem(name: "doctor_id", value: doctorId), URLQueryItem(name: "date", value: date)] }
    var method: HTTPMethod { .get }
}

@MainActor
class BookAppointmentViewModel: ObservableObject {
    @Published var searchQuery = ""
    @Published var searchResults: [PatientSearchResponse] = []
    @Published var selectedPatientId: String? = nil
    
    @Published var doctors: [DirectoryResponse.Doctor] = []
    @Published var departments: [DirectoryResponse.Department] = []
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
            self.departments = directory.departments
        } catch {
            self.errorMessage = "Failed to fetch doctors: \(error.localizedDescription)"
        }
    }
    
    func fetchSlots() async {
        selectedSlot = nil
        availableSlots = []
        guard let doctorId = selectedDoctorId else { return }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
            formatter.timeZone = TimeZone(identifier: "Asia/Kolkata")
        let dateString = formatter.string(from: selectedDate)
        
        do {
            let slots: [Slot] = try await apiClient.execute(endpoint: SlotsEndpoint(doctorId: doctorId, date: dateString))
            self.availableSlots = slots
        } catch {
            self.errorMessage = "Failed to fetch slots: \(error.localizedDescription)"
            self.availableSlots = []
        }
    }
    
    func bookAppointment() async -> Bool {
        guard let pId = selectedPatientId, let dId = selectedDoctorId, let slot = selectedSlot else { return false }
        guard !isSubmitting else { return false }
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
    @Published var departments: [DirectoryResponse.Department] = []
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    @Published var isSubmitting = false
    
    let apiClient = APIClient()
    
    func fetchStaff() async {
        do {
            let directory: DirectoryResponse = try await apiClient.execute(endpoint: DirectoryEndpoint())
            self.departments = directory.departments
        } catch {}

        isLoading = true
        errorMessage = nil
        do {
            let list: [StaffMember] = try await apiClient.execute(endpoint: StaffListEndpoint())
            self.staffMembers = list
        } catch {
            if (error as NSError).domain == NSURLErrorDomain && (error as NSError).code == NSURLErrorCancelled { return }
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func createStaff(id: String, name: String, role: String, department: String, password: String) async -> Bool {
        do {
            struct AnyResponse: Codable {}
            let _: AnyResponse = try await apiClient.execute(endpoint: CreateStaffEndpoint(payload: [
                "id": id, "name": name, "role": role, "department": department, "password": password
            ]))
            await fetchStaff()
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            return false
        }
    }
    
    func updateStaff(staffId: String, name: String, role: String, department: String) async -> Bool {
        isSubmitting = true
        errorMessage = nil
        do {
            struct Empty: Codable {}
            let _: Empty = try await apiClient.execute(endpoint: UpdateStaffEndpoint(staffId: staffId, payload: [
                "name": name,
                "role": role,
                "department": department
            ]))
            await fetchStaff()
            isSubmitting = false
            return true
        } catch {
            self.errorMessage = error.localizedDescription
            isSubmitting = false
            return false
        }
    }

    func toggleStaff(staffId: String, active: Bool) async {
        do {
            struct AnyResponse: Codable {}
            let _: AnyResponse = try await apiClient.execute(endpoint: ToggleStaffEndpoint(staffId: staffId, active: active))
            await fetchStaff()
        } catch {
            if (error as NSError).domain == NSURLErrorDomain && (error as NSError).code == NSURLErrorCancelled { return }
            self.errorMessage = error.localizedDescription
        }
    }
}

struct CreateStaffEndpoint: APIEndpoint {
    let payload: [String: String]
    var path: String { "/api/v1/opd/staff" }
    var method: HTTPMethod { .post }
    var body: Data? { try? JSONSerialization.data(withJSONObject: payload) }
}

struct UpdateStaffEndpoint: APIEndpoint {
    let staffId: String
    let payload: [String: String]
    var path: String { "/api/v1/opd/staff/\(staffId)" }
    var method: HTTPMethod { .put }
    var body: Data? { try? JSONSerialization.data(withJSONObject: payload) }
}

struct ToggleStaffEndpoint: APIEndpoint {
    let staffId: String
    let active: Bool
    var path: String { "/api/v1/opd/staff/\(staffId)" }
    var method: HTTPMethod { .patch }
    var body: Data? { try? JSONSerialization.data(withJSONObject: ["active": active]) }
}

struct AdminMetricsEndpoint: APIEndpoint {
    var path: String { "/api/v1/opd/dashboard" }
    var method: HTTPMethod { .get }
}

struct AdminMetricsResponse: Codable {
    struct DoctorMetric: Codable, Identifiable {
        let name: String
        let appointments: Int
        let waiting: Int
        let completed: Int
        let average_consultation: Double?
        var id: String { name }
    }
    let date: String
    let appointments: Int
    let checked_in: Int
    let waiting: Int
    let triage: Int
    let consultation: Int
    let completed: Int
    let doctors: [DoctorMetric]
}

@MainActor
class AdminMetricsViewModel: ObservableObject {
    @Published var metrics: AdminMetricsResponse?
    @Published var errorMessage: String? = nil
    let apiClient = APIClient()
    
    func fetchMetrics() async {
        do {
            let res: AdminMetricsResponse = try await apiClient.execute(endpoint: AdminMetricsEndpoint())
            self.metrics = res
        } catch {
            if (error as NSError).domain == NSURLErrorDomain && (error as NSError).code == NSURLErrorCancelled { return }
            self.errorMessage = error.localizedDescription
        }
    }
}


struct AdminConfirmEndpoint: APIEndpoint {
    let appointmentId: String
    var path: String { "/api/v1/opd/appointments/\(appointmentId)/confirm" }
    var method: HTTPMethod { .post }
    var body: Data? { try? JSONSerialization.data(withJSONObject: ["__v": 1]) }
}
