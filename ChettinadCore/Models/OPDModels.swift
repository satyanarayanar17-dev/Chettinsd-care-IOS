import Foundation

public struct UserSession: Codable {
    public let id: String
    public let name: String
    public let role: String
    public let department: String?
    public let patient_id: String?
    @FlexibleBool public var must_change_password: Bool
}

public struct OPDSessionEndpoint: APIEndpoint {
    public var path: String { "/api/v1/opd/session" }
    public var method: HTTPMethod { .get }
    
    public init() {}
}

public struct Patient: Codable, Identifiable {
    public let id: String
    public let mrn: String
    public let name: String
    public let phone: String
    public let dob: String
    public let gender: String
    public let email: String?
    public let address: String?
    public let city: String?
    public let state: String?
    public let pin_code: String?
    public let emergency_contact: String?
    public let preferred_language: String?
    public let existing_mrn: String?
    public let allergies: String?
    public let __v: Int
}

public struct Encounter: Codable, Identifiable {
    public let id: String
    public let patient_id: String
    public let assigned_doctor_id: String?
    public let chief_complaint: String?
    public let triage_vitals_json: String?
    public let triaged_by: String?
    public let triaged_at: String?
    public let phase: String
    public let lifecycle_status: String
    public let is_discharged: Bool // actually Int in SQLite, but usually Codable bool works if 0/1 mapped? Better use Int to be safe. Wait, SQLite boolean is mapped as integer in JS, but might be sent as number or bool. Let's use Int or Bool. We'll use Int to be safe or Bool if custom decoded. Let's use Int.
    public let __v: Int
    
    public var discharged: Bool {
        return is_discharged
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, patient_id, assigned_doctor_id, chief_complaint, triage_vitals_json, triaged_by, triaged_at, phase, lifecycle_status, __v
        case is_dischargedBool = "is_discharged"
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        patient_id = try container.decode(String.self, forKey: .patient_id)
        assigned_doctor_id = try container.decodeIfPresent(String.self, forKey: .assigned_doctor_id)
        chief_complaint = try container.decodeIfPresent(String.self, forKey: .chief_complaint)
        triage_vitals_json = try container.decodeIfPresent(String.self, forKey: .triage_vitals_json)
        triaged_by = try container.decodeIfPresent(String.self, forKey: .triaged_by)
        triaged_at = try container.decodeIfPresent(String.self, forKey: .triaged_at)
        phase = try container.decode(String.self, forKey: .phase)
        lifecycle_status = try container.decode(String.self, forKey: .lifecycle_status)
        __v = try container.decode(Int.self, forKey: .__v)
        
        if let boolVal = try? container.decode(Bool.self, forKey: .is_dischargedBool) {
            is_discharged = boolVal
        } else if let intVal = try? container.decode(Int.self, forKey: .is_dischargedBool) {
            is_discharged = intVal != 0
        } else {
            is_discharged = false
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(patient_id, forKey: .patient_id)
        try container.encodeIfPresent(assigned_doctor_id, forKey: .assigned_doctor_id)
        try container.encodeIfPresent(chief_complaint, forKey: .chief_complaint)
        try container.encodeIfPresent(triage_vitals_json, forKey: .triage_vitals_json)
        try container.encodeIfPresent(triaged_by, forKey: .triaged_by)
        try container.encodeIfPresent(triaged_at, forKey: .triaged_at)
        try container.encode(phase, forKey: .phase)
        try container.encode(lifecycle_status, forKey: .lifecycle_status)
        try container.encode(__v, forKey: .__v)
        try container.encode(is_discharged, forKey: .is_dischargedBool)
    }
}

public struct RecordBundle: Codable {
    public let patient: Patient
    public let encounters: [Encounter]
    public let triage: [TriageRecord]
    public let notes: [Note]
    public let prescriptions: [Prescription]
    public let labs: [LabOrder]
}

public struct TriageRecord: Codable, Identifiable {
    public let id: String
    public let encounter_id: String
    public let version: Int
    public let data: TriageData?
    public let nurse_id: String?
    public let created_at: String
}

public struct TriageData: Codable, Sendable {
    public let temperature: Double?
    public let systolic: Int?
    public let diastolic: Int?
    public let pulse: Int?
    public let spo2: Int?
    public let weight: Double?
    public let height: Double?
    public let complaint: String?
    public let allergies: String?
    public let pain: Int?
    public let notes: String?
    public let priority: Int?
    public let bmi: Double?
}

public struct Note: Codable, Identifiable {
    public let id: String
    public let encounter_id: String
    public let status: String
    public let author_id: String
    public let created_at: String
    public let draft_content: NoteContent?
    public let author_name: String?
}

public struct NoteDiagnosis: Codable, Sendable {
    public let id: String
    public let name: String
}

public struct NoteMedication: Codable, Sendable {
    public let drug_id: String
    public let dose: String
    public let frequency: String
    public let duration: String
    public let instructions: String?
    public let name: String
    public let strength: String
    public let form: String
    public let route: String
}

public struct NoteContent: Codable, Sendable {
    public let complaint: String?
    public let history: String?
    public let previous_history: String?
    public let examination: String?
    public let assessment: String?
    public let diagnoses: [NoteDiagnosis]?
    public let treatment: String?
    public let advice: String?
    public let medications: [NoteMedication]?
}

public struct Prescription: Codable, Identifiable {
    public let id: String
    public let encounter_id: String
    public let status: String
    public let authorizing_user_id: String
    public let created_at: String
    public let rx_content: PrescriptionContent?
    public let doctor_name: String?
}

public struct PrescriptionContent: Codable, Sendable {
    public let medications: [NoteMedication]?
    public let diagnoses: [NoteDiagnosis]?
    public let advice: String?
}

public struct LabOrder: Codable, Identifiable {
    public let id: String
    public let encounter_id: String
    public let test_id: String
    public let ordered_by: String
    public let ordered_at: String
    public let status: String
    public let patient_name: String?
    public let name: String? // test name
    public let code: String?
    public let unit: String?
    public let reference_range: String?
    public let result: String?
}

public struct QueueEntry: Codable, Identifiable {
    public var id: String { encounter_id }
    public let encounter_id: String
    public let patient_id: String
    public let patient_name: String
    public let mrn: String
    public let status: String
    public let token: String
    public let doctor_id: String
    public let doctor_name: String
    public let priority: Int
    public let __v: Int
}

public struct QueueEndpoint: APIEndpoint {
    public var path: String { "/api/v1/opd/queue" }
    public var method: HTTPMethod { .get }
    public init() {}
}

public struct Appointment: Codable, Identifiable {
    public let id: String
    public let patient_id: String
    public let doctor_id: String
    public let scheduled_at: String
    public let status: String
    public let reason: String?
    public let encounter_id: String?
    public let follow_up_of: String?
    public let __v: Int?
}
