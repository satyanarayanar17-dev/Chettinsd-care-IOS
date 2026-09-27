import SwiftUI
import ChettinadCore


struct PatientSelfRecordPayload: Encodable {
    let record_type: String
    let timing_context: String?
    let numeric_value: Double?
    let secondary_numeric_value: Double?
    let unit: String?
    let activity_name: String?
    let duration_minutes: Int?
    let observed_at: String
    let patient_note: String?
}

struct AddPatientSelfRecordEndpoint: APIEndpoint {
    let patientId: String
    let payload: PatientSelfRecordPayload
    var path: String { "/api/v1/opd/patient-self-records/\(patientId)" }
    var method: HTTPMethod { .post }
    var body: Data? { try? JSONEncoder().encode(payload) }
}

struct LogActivitySheet: View {
    @Environment(\.dismiss) private var dismiss
    let patientId: String
    let onRecordAdded: () async -> Void
    
    let activities = ["Walking", "Running", "Badminton", "Other Games", "Cycling", "Swimming", "Yoga", "Gym"]
    @State private var selectedActivity = "Walking"
    @State private var customActivity = ""
    @State private var duration = ""
    @State private var observedAt = Date()
    @State private var note = ""
    @State private var saving = false
    @State private var errorMessage: String? = nil
    
    let apiClient = APIClient()
    
    var body: some View {
        NavigationView {
            Form {
                if let error = errorMessage {
                    Section { Text(error).foregroundColor(.red) }
                }
                
                Section(header: Text("What activity has the patient done?")) {
                    Picker("Select Activity", selection: $selectedActivity) {
                        ForEach(activities, id: \.self) {
                            Text($0).tag($0)
                        }
                    }
                    
                    if selectedActivity == "Other Games" {
                        TextField("Enter activity name", text: $customActivity)
                    }
                    
                    TextField("How long? (Duration in minutes)", text: $duration)
                        .keyboardType(.numberPad)
                    
                    DatePicker("When", selection: $observedAt)
                    
                    TextField("Optional note", text: $note, axis: .vertical)
                }
                
                Section {
                    Text("This activity is logged as a patient record. It can be seen in their Care Plan by the patient and other clinical staff.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Log Activity")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { 
                    Button("Cancel") { dismiss() } 
                }
                ToolbarItem(placement: .confirmationAction) { 
                    Button(saving ? "Saving…" : "Save") { save() }
                        .disabled(!valid || saving) 
                }
            }
        }
    }
    
    private var valid: Bool {
        let act = selectedActivity == "Other Games" ? customActivity : selectedActivity
        return !act.trimmingCharacters(in: .whitespaces).isEmpty && Int(duration) != nil
    }
    
    private func save() {
        saving = true
        errorMessage = nil
        let act = selectedActivity == "Other Games" ? customActivity : selectedActivity
        let payload = PatientSelfRecordPayload(
            record_type: "ACTIVITY",
            timing_context: nil,
            numeric_value: nil,
            secondary_numeric_value: nil,
            unit: nil,
            activity_name: act,
            duration_minutes: Int(duration),
            observed_at: ISO8601DateFormatter().string(from: observedAt),
            patient_note: note.isEmpty ? nil : note
        )
        Task {
            do {
                struct AnyResponse: Codable {}
                let _: AnyResponse = try await apiClient.execute(endpoint: AddPatientSelfRecordEndpoint(patientId: patientId, payload: payload))
                await onRecordAdded()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                saving = false
            }
        }
    }
}
