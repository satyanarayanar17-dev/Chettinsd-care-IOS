import Foundation

// Triage Data
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

// Note Content
public struct NoteDiagnosis: Codable, Sendable {
    public let id: String
    public let name: String
}

public struct NoteMedication: Codable, Sendable {
    public let drug_id: String
    public let dose: String
    public let frequency: String
    public let duration: String
    public let instructions: String
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

// Prescription Content
public struct PrescriptionContent: Codable, Sendable {
    public let medications: [NoteMedication]?
    public let diagnoses: [NoteDiagnosis]?
    public let advice: String?
}
