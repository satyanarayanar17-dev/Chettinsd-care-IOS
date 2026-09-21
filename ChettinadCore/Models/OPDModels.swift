import Foundation

public struct UserSession: Codable {
    public let id: String
    public let name: String
    public let role: String
    public let department: String?
    public let patient_id: String?
    public let must_change_password: Bool
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
