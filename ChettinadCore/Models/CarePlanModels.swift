import Foundation

public struct CarePlan: Codable, Identifiable, Sendable {
    public let id: String
    public let patient_id: String
    public let department_id: String
    public let status: String
    public let timezone: String
    public let start_date: String
    public let end_date: String?
    public let __v: Int
}

public enum CarePlanTaskType: String, Codable, Sendable {
    case MEASUREMENT, ACTIVITY, MEDICATION, INSULIN
}

public enum CarePlanOccurrenceStatus: String, Codable, Sendable {
    case UPCOMING, DUE, COMPLETED, MISSED, SKIPPED
}

public struct ObservationComponent: Codable, Sendable {
    public let component_code: String
    public let numeric_value: Double
    public let unit: String

    private enum CodingKeys: String, CodingKey { case component_code, numeric_value, unit }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        component_code = try values.decode(String.self, forKey: .component_code)
        unit = try values.decode(String.self, forKey: .unit)
        if let number = try? values.decode(Double.self, forKey: .numeric_value) {
            numeric_value = number
        } else {
            let text = try values.decode(String.self, forKey: .numeric_value)
            guard let number = Double(text) else {
                throw DecodingError.dataCorruptedError(forKey: .numeric_value, in: values, debugDescription: "Expected a numeric value")
            }
            numeric_value = number
        }
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(component_code, forKey: .component_code)
        try values.encode(numeric_value, forKey: .numeric_value)
        try values.encode(unit, forKey: .unit)
    }
}

public struct PatientObservation: Codable, Identifiable, Sendable {
    public let id: String
    public let adherence_id: String
    public let observation_type: String
    public let timing_relation: String
    public let observed_at: String
    public let recorded_at: String
    public let components: [ObservationComponent]?
}

public struct MedicationSource: Codable, Sendable {
    public let prescription_id: String
    public let prescription_item_id: String
    public let prescription_version: Int
    public let drug_name: String
    public let strength: String
    public let form: String
    public let route: String
    public let dose: String
    public let frequency: String
    public let duration: String
    public let instructions: String
    public let outdated: Bool
}

/// Exact flat DTO returned by `/adherence/:patientId/today` and `/record`.
public struct CarePlanOccurrenceDTO: Codable, Identifiable, Sendable {
    public let id: String
    public let task_id: String
    public let plan_id: String
    public let series_id: String
    public let revision: Int
    public let task_type: CarePlanTaskType
    public let title: String
    public let description: String
    public let instruction: String
    public let target_metric: String?
    public let observation_type: String?
    public let timing_relation: String?
    public let target_unit: String?
    public let occurrence_date: String
    public let due_date: String
    public let due_time: String
    public let scheduled_for: String
    public let status: CarePlanOccurrenceStatus
    public let response_status: String?
    public let completed_at: String?
    public let recorded_at: String?
    public let recorded_value: Double?
    public let patient_note: String?
    public let __v: Int
    public let observation: PatientObservation?
    public let medication_source: MedicationSource?

    private enum CodingKeys: String, CodingKey {
        case id, task_id, plan_id, series_id, revision, task_type, title, description, instruction
        case target_metric, observation_type, timing_relation, target_unit, occurrence_date, due_date, due_time
        case scheduled_for, status, response_status, completed_at, recorded_at, recorded_value, patient_note, __v
        case observation, medication_source
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        task_id = try values.decode(String.self, forKey: .task_id)
        plan_id = try values.decode(String.self, forKey: .plan_id)
        series_id = try values.decode(String.self, forKey: .series_id)
        revision = try values.decode(Int.self, forKey: .revision)
        task_type = try values.decode(CarePlanTaskType.self, forKey: .task_type)
        title = try values.decode(String.self, forKey: .title)
        description = try values.decode(String.self, forKey: .description)
        instruction = try values.decode(String.self, forKey: .instruction)
        target_metric = try values.decodeIfPresent(String.self, forKey: .target_metric)
        observation_type = try values.decodeIfPresent(String.self, forKey: .observation_type)
        timing_relation = try values.decodeIfPresent(String.self, forKey: .timing_relation)
        target_unit = try values.decodeIfPresent(String.self, forKey: .target_unit)
        occurrence_date = try values.decode(String.self, forKey: .occurrence_date)
        due_date = try values.decode(String.self, forKey: .due_date)
        due_time = try values.decode(String.self, forKey: .due_time)
        scheduled_for = try values.decode(String.self, forKey: .scheduled_for)
        status = try values.decode(CarePlanOccurrenceStatus.self, forKey: .status)
        response_status = try values.decodeIfPresent(String.self, forKey: .response_status)
        completed_at = try values.decodeIfPresent(String.self, forKey: .completed_at)
        recorded_at = try values.decodeIfPresent(String.self, forKey: .recorded_at)
        patient_note = try values.decodeIfPresent(String.self, forKey: .patient_note)
        __v = try values.decode(Int.self, forKey: .__v)
        observation = try values.decodeIfPresent(PatientObservation.self, forKey: .observation)
        medication_source = try values.decodeIfPresent(MedicationSource.self, forKey: .medication_source)
        if let number = try? values.decodeIfPresent(Double.self, forKey: .recorded_value) {
            recorded_value = number
        } else if let text = try values.decodeIfPresent(String.self, forKey: .recorded_value) {
            recorded_value = Double(text)
        } else {
            recorded_value = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(task_id, forKey: .task_id)
        try values.encode(plan_id, forKey: .plan_id)
        try values.encode(series_id, forKey: .series_id)
        try values.encode(revision, forKey: .revision)
        try values.encode(task_type, forKey: .task_type)
        try values.encode(title, forKey: .title)
        try values.encode(description, forKey: .description)
        try values.encode(instruction, forKey: .instruction)
        try values.encodeIfPresent(target_metric, forKey: .target_metric)
        try values.encodeIfPresent(observation_type, forKey: .observation_type)
        try values.encodeIfPresent(timing_relation, forKey: .timing_relation)
        try values.encodeIfPresent(target_unit, forKey: .target_unit)
        try values.encode(occurrence_date, forKey: .occurrence_date)
        try values.encode(due_date, forKey: .due_date)
        try values.encode(due_time, forKey: .due_time)
        try values.encode(scheduled_for, forKey: .scheduled_for)
        try values.encode(status, forKey: .status)
        try values.encodeIfPresent(response_status, forKey: .response_status)
        try values.encodeIfPresent(completed_at, forKey: .completed_at)
        try values.encodeIfPresent(recorded_at, forKey: .recorded_at)
        try values.encodeIfPresent(recorded_value, forKey: .recorded_value)
        try values.encodeIfPresent(patient_note, forKey: .patient_note)
        try values.encode(__v, forKey: .__v)
        try values.encodeIfPresent(observation, forKey: .observation)
        try values.encodeIfPresent(medication_source, forKey: .medication_source)
    }
}

public struct CarePlanTaskDTO: Codable, Identifiable, Sendable {
    public let id: String
    public let series_id: String
    public let revision: Int
    public let plan_id: String
    public let supersedes_task_id: String?
    public let task_type: CarePlanTaskType
    public let title: String
    public let instruction: String
    public let observation_type: String?
    public let timing_relation: String?
    public let target_unit: String?
    public let prescription_item_id: String?
    public let frequency_type: String
    public let scheduled_time: String
    public let start_date: String
    public let end_date: String?
    public let expected_duration_minutes: Int?
    public let window_before_minutes: Int
    public let window_after_minutes: Int
    public let status: String
    public let drug_name: String?
    public let dose: String?
    public let frequency: String?
    public let medication_source_outdated: Bool?
}

/// Exact persisted row shape returned by `/adherence/:patientId/timeline`.
public struct AdherenceResponseDTO: Codable, Identifiable, Sendable {
    public let id: String
    public let task_id: String
    public let patient_id: String
    public let occurrence_date: String
    public let scheduled_for: String
    public let status: String
    public let completed_at: String?
    public let recorded_at: String
    public let patient_note: String?
    public let __v: Int
    public let task_type: CarePlanTaskType?
    public let title: String?
    public let instruction: String?
    public let series_id: String?
    public let revision: Int?
    public let observation_type: String?
    public let timing_relation: String?
    public let prescription_id: String?
    public let prescription_version: Int?
    public let dose: String?
    public let frequency: String?
    public let drug_name: String?
    public let observation: PatientObservation?
}

public struct RecordAdherencePayload: Codable, Sendable {
    public let __v: Int
    public let date: String
    public let status: String
    public let value: Double?
    public let unit: String?
    public let note: String?

    public init(__v: Int, date: String, status: String, value: Double?, unit: String?, note: String?) {
        self.__v = __v
        self.date = date
        self.status = status
        self.value = value
        self.unit = unit
        self.note = note
    }
}
