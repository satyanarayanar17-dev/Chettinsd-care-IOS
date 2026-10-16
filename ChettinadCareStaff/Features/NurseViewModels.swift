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
        let patient__v: Int?
        let allergy_review_confirmed: Bool
        let allergy_change_reason: String?
        let reason: String?
    }
    
    let encounterId: String
    let v: Int
    let data: TriageData
    var patientVersion: Int? = nil
    var allergyReviewed = false
    var allergyReason: String? = nil
    var amendmentReason: String? = nil
    var path: String { "/api/v1/opd/encounters/\(encounterId)/triage" }
    var method: HTTPMethod { .post }
    var body: Data? { try? JSONEncoder().encode(Payload(__v:v,data:data,patient__v:patientVersion,allergy_review_confirmed:allergyReviewed,allergy_change_reason:allergyReason,reason:amendmentReason)) }
}

// MARK: - Nurse Triage ViewModel

@MainActor
final class NurseTriageViewModel: StaffQueueViewModel {
    init(apiClient: APIClient = APIClient()) { super.init(role: "NURSE", apiClient: apiClient) }
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
    @Published var patient: Patient?
    @Published var allergies = ""
    @Published var allergyStatus = "UNKNOWN"
    @Published var allergyReviewConfirmed = false
    @Published var allergyChangeReason = ""
    @Published var amendmentReason = ""
    @Published var hasPreviousTriage = false
    
    @Published var isLoading = false
    @Published var isSubmitting = false
    @Published var errorMessage: String? = nil
    
    let apiClient: APIClient
    
    init(encounterId: String, initialVersion: Int, apiClient: APIClient = APIClient()) {
        self.encounterId = encounterId
        self.currentVersion = initialVersion
        self.apiClient = apiClient
    }
    
    var editableSnapshot: [String] { [temperature,systolic,diastolic,pulse,spo2,weight,height,pain,notes,String(priority),complaint,allergies,allergyStatus,String(allergyReviewConfirmed),allergyChangeReason,amendmentReason] }
    func startTriage() async -> Bool {
        isLoading = true
        errorMessage = nil
        do {
            let queue: [QueueEntry] = try await apiClient.execute(endpoint: QueueEndpoint())
            guard let entry = queue.first(where: { $0.encounter_id == encounterId }) else { throw APIError.invalidResponse }
            currentVersion = entry.__v
            let record: RecordBundle = try await apiClient.execute(endpoint:PatientRecordEndpoint(patientId:entry.patient_id))
            guard record.patient.id == entry.patient_id else { throw APIError.invalidResponse }
            patient = record.patient; allergies = record.patient.allergies ?? ""
            allergyStatus = record.patient.allergy_review_status ?? (allergies.isEmpty ? "UNKNOWN" : "RECORDED")
            if let previous = record.triage.first(where: { $0.encounter_id == encounterId }), let data = previous.data {
                hasPreviousTriage = true
                temperature = data.temperature.map { String($0) } ?? ""; systolic = data.systolic.map { String($0) } ?? ""
                diastolic = data.diastolic.map { String($0) } ?? ""; pulse = data.pulse.map { String($0) } ?? ""
                spo2 = data.spo2.map { String($0) } ?? ""; weight = data.weight.map { String($0) } ?? ""; height = data.height.map { String($0) } ?? ""
                pain = data.pain.map { String($0) } ?? ""; complaint = data.complaint ?? ""; notes = data.notes ?? ""; priority = data.priority ?? 0
            }
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

        if let problem = validationError { errorMessage = problem; isSubmitting = false; return false }

        // Never silently drop a vital the nurse typed: reject anything that isn't a number.
        let numericFields: [(label: String, value: String, isInteger: Bool)] = [
            ("Temperature", temperature, false), ("Systolic BP", systolic, true), ("Diastolic BP", diastolic, true),
            ("Pulse", pulse, true), ("SpO2", spo2, true), ("Weight", weight, false), ("Height", height, false), ("Pain", pain, true)
        ]
        let invalid = numericFields.filter { Self.clean($0.value).isEmpty || Self.isInvalidNumber($0.value, integer: $0.isInteger) }.map { $0.label }
        guard invalid.isEmpty else {
            errorMessage = "Please correct: \(invalid.joined(separator: ", ")) (numbers only)."
            isSubmitting = false
            return false
        }
        let bounds: [(String,String,Double,Double)] = [("Temperature",temperature,25,45),("Systolic BP",systolic,40,300),("Diastolic BP",diastolic,20,200),("Pulse",pulse,20,250),("SpO2",spo2,1,100),("Weight",weight,0.5,500),("Height",height,20,250),("Pain",pain,0,10)]
        if let invalid = bounds.first(where: { value in guard let n = Self.decimal(value.1) else { return true };return n < value.2 || n > value.3 }) {
            errorMessage = "\(invalid.0) must be between \(invalid.2) and \(invalid.3).";isSubmitting=false;return false
        }
        let trimmedComplaint = complaint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedComplaint.isEmpty else {
            errorMessage = "Enter the complaint before submitting."
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
            allergies: allergyReviewConfirmed ? allergies : nil,
            pain: Self.integer(pain),
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            priority: priority,
            bmi: nil,
            allergy_review_status: allergyReviewConfirmed ? allergyStatus : nil
        )
        
        do {
            let response: EncounterMutationResponse = try await apiClient.execute(
                endpoint: SubmitTriageEndpoint(encounterId:encounterId,v:currentVersion,data:tData,patientVersion:patient?.__v,allergyReviewed:allergyReviewConfirmed,allergyReason:allergyChangeReason.isEmpty ? nil : allergyChangeReason,amendmentReason:hasPreviousTriage ? amendmentReason : nil)
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
        guard let value = Double(t), value.isFinite else { return nil };return value
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
