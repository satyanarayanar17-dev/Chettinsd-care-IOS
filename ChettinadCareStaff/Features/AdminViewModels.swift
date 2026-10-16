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
    let dob: String?
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
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var mutationsInFlight: Set<String> = []
    private var currentLoad: UUID?
    let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) { self.apiClient = apiClient }

    func fetchAppointments(for date: Date = Date(), requestsOnly: Bool = false) async {
        let load = UUID()
        currentLoad = load
        isLoading = true
        defer { if currentLoad == load { isLoading = false } }
        errorMessage = nil
        do {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
            formatter.timeZone = TimeZone(identifier: "Asia/Kolkata")
            let fetched: [Appointment]
            if requestsOnly { fetched = try await apiClient.execute(endpoint: AdminAllAppointmentsEndpoint()) }
            else { fetched = try await apiClient.execute(endpoint: AdminAppointmentsEndpoint(date: formatter.string(from: date))) }
            guard !Task.isCancelled, currentLoad == load else { return }
            appointments = requestsOnly ? fetched.filter { $0.status == "PENDING_CONFIRMATION" } : fetched
        } catch {
            guard !Task.isCancelled, currentLoad == load, (error as NSError).code != NSURLErrorCancelled else { return }
            errorMessage = "We couldn't load the appointments. Please retry."
        }
    }

    func confirmAppointment(appointmentId: String) async -> Bool {
        guard !mutationsInFlight.contains(appointmentId) else { return false }
        mutationsInFlight.insert(appointmentId)
        defer { mutationsInFlight.remove(appointmentId) }
        errorMessage = nil
        do {
            let _: EmptyResponse = try await apiClient.execute(endpoint: AdminConfirmEndpoint(appointmentId: appointmentId))
            return true
        } catch { errorMessage = "Confirm failed: \(error.localizedDescription)"; return false }
    }

    func checkIn(appointmentId: String) async -> Bool {
        guard !mutationsInFlight.contains(appointmentId) else { return false }
        mutationsInFlight.insert(appointmentId)
        defer { mutationsInFlight.remove(appointmentId) }
        errorMessage = nil
        do {
            let _: EncounterMutationResponse = try await apiClient.execute(endpoint: AdminCheckInEndpoint(appointmentId: appointmentId))
            return true
        } catch { errorMessage = "Check-in failed: \(error.localizedDescription)"; return false }
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
    @Published var searchQuery = "" {
        didSet {
            if searchQuery != oldValue {
                searchRevision += 1; searchResults = []; selectedPatientId = nil; isSearching = false
            }
        }
    }
    @Published var searchResults: [PatientSearchResponse] = []
    @Published var selectedPatientId: String? = nil
    
    @Published var doctors: [DirectoryResponse.Doctor] = []
    @Published var departments: [DirectoryResponse.Department] = []
    @Published var selectedDoctorId: String? = nil { didSet { if selectedDoctorId != oldValue { invalidateSlots() } } }
    
    @Published var selectedDate = Date() { didSet { if selectedDate != oldValue { invalidateSlots() } } }
    @Published var availableSlots: [Slot] = []
    @Published var selectedSlot: String? = nil
    
    @Published var reason = "Routine Consultation"
    
    @Published var isSearching = false
    @Published var isSubmitting = false
    @Published var errorMessage: String? = nil
    
    let apiClient: APIClient
    init(apiClient: APIClient = APIClient()) { self.apiClient = apiClient }
    
    private var searchRevision = 0
    private var slotsRevision = 0
    private var loadedSlotsDoctor: String?
    private var loadedSlotsDay: String?

    private func invalidateSlots() {
        slotsRevision += 1; selectedSlot = nil; availableSlots = []
        loadedSlotsDoctor = nil; loadedSlotsDay = nil
    }
    private func hospitalDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "Asia/Kolkata"); formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    func searchPatients() async {
        searchRevision += 1
        let revision = searchRevision
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        searchResults = []; selectedPatientId = nil
        guard query.count > 2 else { isSearching = false; return }
        isSearching = true
        defer { if revision == searchRevision { isSearching = false } }
        do {
            let results: [PatientSearchResponse] = try await apiClient.execute(endpoint: PatientSearchEndpoint(query: query))
            guard !Task.isCancelled, revision == searchRevision else { return }
            searchResults = results
        } catch {
            guard !Task.isCancelled, revision == searchRevision else { return }
            errorMessage = "Search failed: \(error.localizedDescription)"
        }
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
        invalidateSlots()
        let revision = slotsRevision
        guard let doctorId = selectedDoctorId else { return }
        let day = hospitalDay(selectedDate)
        do {
            let slots: [Slot] = try await apiClient.execute(endpoint: SlotsEndpoint(doctorId: doctorId, date: day))
            guard !Task.isCancelled, revision == slotsRevision, selectedDoctorId == doctorId,
                  hospitalDay(selectedDate) == day else { return }
            availableSlots = slots; loadedSlotsDoctor = doctorId; loadedSlotsDay = day
        } catch {
            guard !Task.isCancelled, revision == slotsRevision else { return }
            errorMessage = "Failed to fetch slots: \(error.localizedDescription)"
        }
    }

    func bookAppointment() async -> Bool {
        guard let pId = selectedPatientId, searchResults.contains(where: { $0.id == pId }),
              let dId = selectedDoctorId, let slot = selectedSlot,
              loadedSlotsDoctor == dId, loadedSlotsDay == hospitalDay(selectedDate),
              availableSlots.contains(where: { $0.scheduled_at == slot }) else { return false }
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
    struct DepartmentMetric: Codable {
        let name: String
        let patients: Int
        let waiting: Int
        let average_wait: Int?
        let longest_wait: Int?
    }
    let date: String
    let requires_action: Int
    let security_alerts: Int
    let today_confirmed: Int
    let upcoming: Int
    let appointments: Int
    let checked_in: Int
    let waiting: Int
    let triage: Int
    let consultation: Int
    let completed: Int
    let no_shows: Int
    let average_wait: Int?
    let results_pending: Int
    let doctors: [DoctorMetric]
    let departments: [DepartmentMetric]?
}

@MainActor
class AdminMetricsViewModel: ObservableObject {
    @Published var metrics: AdminMetricsResponse?
    @Published var errorMessage: String?
    @Published var isLoading = false
    let apiClient: APIClient

    init(apiClient: APIClient = APIClient()) { self.apiClient = apiClient }

    func fetchMetrics() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            let result: AdminMetricsResponse = try await apiClient.execute(endpoint: AdminMetricsEndpoint())
            guard !Task.isCancelled else { return }
            metrics = result
        } catch {
            guard !Task.isCancelled, (error as NSError).code != NSURLErrorCancelled else { return }
            errorMessage = "We couldn't load the overview. Please try again."
        }
    }
}

struct AdminConfirmEndpoint: APIEndpoint {
    let appointmentId: String
    var path: String { "/api/v1/opd/appointments/\(appointmentId)/confirm" }
    var method: HTTPMethod { .post }
    var body: Data? { try? JSONSerialization.data(withJSONObject: ["__v": 1]) }
}

struct AdminAllAppointmentsEndpoint: APIEndpoint {
    var path: String { "/api/v1/opd/appointments" }
    var method: HTTPMethod { .get }
}

struct OPDUnavailability: Codable, Identifiable {
    let id: String
    let doctor_id: String
    let date: String
    let reason: String
}


struct UnavailabilityEndpoint: APIEndpoint {
    typealias Response = [OPDUnavailability]
    var path: String { "/api/v1/opd/unavailability" }
    var method: HTTPMethod { .get }
}

struct CreateUnavailabilityEndpoint: APIEndpoint {
    typealias Response = EmptyResponse
    var path: String { "/api/v1/opd/unavailability" }
    var method: HTTPMethod { .post }
    var body: Data?
    
    struct Payload: Codable {
        let doctor_id: String
        let date: String
        let reason: String
    }
    
    init(payload: Payload) {
        self.body = try? JSONEncoder().encode(payload)
    }
}

struct DeleteUnavailabilityEndpoint: APIEndpoint {
    typealias Response = EmptyResponse
    let id: String
    var path: String { "/api/v1/opd/unavailability/\(id)" }
    var method: HTTPMethod { .delete }
}


@MainActor
class DoctorScheduleViewModel: ObservableObject {
    @Published var directory: OPDDirectory?
    @Published var unavailability: [OPDUnavailability] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    let apiClient = APIClient()
    
    func fetchData() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            async let d: OPDDirectory = apiClient.execute(endpoint: DirectoryEndpoint())
            async let u: [OPDUnavailability] = apiClient.execute(endpoint: UnavailabilityEndpoint())
            let loaded = try await (d, u)
            guard !Task.isCancelled else { return }
            self.directory = loaded.0
            self.unavailability = loaded.1
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func addLeave(doctorId: String, date: String, reason: String) async -> Bool {
        do {
            let payload = CreateUnavailabilityEndpoint.Payload(doctor_id: doctorId, date: date, reason: reason)
            let _: EmptyResponse = try await apiClient.execute(endpoint: CreateUnavailabilityEndpoint(payload: payload))
            await fetchData()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    func deleteLeave(id: String) async {
        do {
            let _: EmptyResponse = try await apiClient.execute(endpoint: DeleteUnavailabilityEndpoint(id: id))
            await fetchData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
