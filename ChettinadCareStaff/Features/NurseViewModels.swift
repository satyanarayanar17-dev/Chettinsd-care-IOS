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
    @Published var appointments: [Appointment] = []
    @Published var isLoading = true
    @Published var errorMessage: String? = nil
    @Published var metrics: AdminMetricsResponse? = nil
    
    let apiClient = APIClient()
    var pendingAppointments: [Appointment] {
        appointments.filter { $0.status == "PENDING_CONFIRMATION" }.sorted { $0.scheduled_at < $1.scheduled_at }
    }
    
    var todayAppointments: [Appointment] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        formatter.timeZone = TimeZone(identifier: "Asia/Kolkata")
        let today = formatter.string(from: Date())
        
        return appointments.filter { 
            ($0.status == "CONFIRMED" || $0.status == "CHECKED_IN" || $0.status == "READY_FOR_DOCTOR" || $0.status == "IN_CONSULTATION") && 
            $0.scheduled_at.hasPrefix(today)
        }.sorted { $0.scheduled_at < $1.scheduled_at }
    }
    
    func confirmAppointment(appointmentId: String) async {
        do {
            struct AnyResponse: Codable {}
            let _: AnyResponse = try await apiClient.execute(endpoint: AdminConfirmEndpoint(appointmentId: appointmentId))
            await fetchQueue()
        } catch {
            self.errorMessage = "Confirm failed: \(error.localizedDescription)"
        }
    }
    
    func checkIn(appointmentId: String) async {
        do {
            struct AnyResponse: Codable {}
            let _: AnyResponse = try await apiClient.execute(endpoint: AdminCheckInEndpoint(appointmentId: appointmentId))
            await fetchQueue()
        } catch {
            self.errorMessage = "Check-in failed: \(error.localizedDescription)"
        }
    }

    
    private var queueFetchInFlight = false
    func fetchQueue() async {
        guard !queueFetchInFlight else { return }
        queueFetchInFlight = true
        defer { queueFetchInFlight = false; isLoading = false }
        if metrics == nil { isLoading = true }
        errorMessage = nil
        do {
            async let fetchedQueueTask: [QueueEntry] = try await apiClient.execute(endpoint: QueueEndpoint())
            async let metricsTask: AdminMetricsResponse = try await apiClient.execute(endpoint: AdminMetricsEndpoint())
            async let appointmentsTask: [Appointment] = {
                do {
                    return try await apiClient.execute(endpoint: AdminAllAppointmentsEndpoint())
                } catch {
                    print("Appointments error:", error)
                    return []
                }
            }()
            let (fetchedQueue, metrics, fetchedAppointments) = try await (fetchedQueueTask, metricsTask, appointmentsTask)
            self.metrics = metrics
            self.appointments = fetchedAppointments
            self.queue = fetchedQueue.filter { $0.status == "WAITING" || $0.status == "TRIAGE" }
        } catch {
            if error is CancellationError { return }
            if (error as NSError).domain == NSURLErrorDomain && (error as NSError).code == NSURLErrorCancelled { return }
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
    @Published var recordedAllergies: String = "Not recorded"
    
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
            let record: RecordBundle = try await apiClient.execute(endpoint: PatientRecordEndpoint(patientId: entry.patient_id))
            recordedAllergies = record.patient.allergies?.isEmpty == false ? record.patient.allergies! : "Not recorded"
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
        guard !isSubmitting else { return false }
        isSubmitting = true
        errorMessage = nil
        if let problem = validationError {
            errorMessage = problem; isSubmitting = false; return false
        }

        // Never silently drop a vital the nurse typed: reject anything that isn't a number.
        let numericFields: [(label: String, value: String, isInteger: Bool)] = [
            ("Temperature", temperature, false), ("Systolic BP", systolic, true), ("Diastolic BP", diastolic, true),
            ("Pulse", pulse, true), ("SpO2", spo2, true), ("Weight", weight, false), ("Height", height, false), ("Pain", pain, true)
        ]
        let invalid = numericFields.filter { Self.isInvalidNumber($0.value, integer: $0.isInteger) }.map { $0.label }
        guard invalid.isEmpty else {
            errorMessage = "Please correct: \(invalid.joined(separator: ", ")) (numbers only)."
            isSubmitting = false
            return false
        }
        let trimmedComplaint = complaint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard numericFields.contains(where: { !Self.clean($0.value).isEmpty }) || !trimmedComplaint.isEmpty else {
            errorMessage = "Enter at least one vital sign or the complaint before submitting."
            isSubmitting = false
            return false
        }
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        let tData = TriageData(
            temperature: Self.decimal(temperature),
            systolic: Self.integer(systolic),
            diastolic: Self.integer(diastolic),
            pulse: Self.integer(pulse),
            spo2: Self.integer(spo2),
            weight: Self.decimal(weight),
            height: Self.decimal(height),
            complaint: trimmedComplaint.isEmpty ? nil : trimmedComplaint,
            allergies: nil,
            pain: Self.integer(pain),
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
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
    
    private static func clean(_ s: String) -> String {
        s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var validationError: String? {
        let values: [(String, Double?, ClosedRange<Double>)] = [
            ("Temperature", Self.decimal(temperature), 25...45), ("Systolic BP", Self.integer(systolic).map(Double.init), 40...300),
            ("Diastolic BP", Self.integer(diastolic).map(Double.init), 20...200), ("Pulse", Self.integer(pulse).map(Double.init), 20...250),
            ("SpO2", Self.integer(spo2).map(Double.init), 1...100), ("Weight", Self.decimal(weight), 0.5...500),
            ("Height", Self.decimal(height), 20...250), ("Pain", Self.integer(pain).map(Double.init), 0...10)
        ]
        if let invalid = values.first(where: { row in guard let value = row.1 else { return true }; return !value.isFinite || !row.2.contains(value) }) {
            return "Enter a valid \(invalid.0) before submitting."
        }
        guard let sys = Self.integer(systolic), let dia = Self.integer(diastolic), sys > dia else { return "Systolic BP must be higher than diastolic BP." }
        return Self.clean(complaint).isEmpty ? "Enter the presenting complaint before submitting." : nil
    }

    private static func decimal(_ s: String) -> Double? {
        let t = clean(s).replacingOccurrences(of: ",", with: ".")
        return t.isEmpty ? nil : Double(t)
    }

    private static func integer(_ s: String) -> Int? {
        let t = clean(s)
        return t.isEmpty ? nil : Int(t)
    }

    private static func isInvalidNumber(_ s: String, integer isInteger: Bool) -> Bool {
        let t = clean(s)
        guard !t.isEmpty else { return false }
        return isInteger ? integer(t) == nil : decimal(t) == nil
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
