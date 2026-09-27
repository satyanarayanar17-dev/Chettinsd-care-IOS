import SwiftUI
import ChettinadCore

struct LogActivitySheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CarePlanViewModel
    
    let activities = ["Walking", "Running", "Badminton", "Other Games", "Cycling", "Swimming", "Yoga", "Gym"]
    @State private var selectedActivity = "Walking"
    @State private var customActivity = ""
    @State private var duration = ""
    @State private var observedAt = Date()
    @State private var note = ""
    @State private var saving = false
    
    var body: some View {
        NavigationView {
            Form {
                if let error = viewModel.errorMessage {
                    Section { Text(error).foregroundColor(.red) }
                }
                
                Section(header: Text("What activity have you done?")) {
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
                    Text("This activity is logged as a patient record. It can be seen in your Care Plan, and will be visible to your doctor and nurse as well.")
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
            if await viewModel.addSelfRecord(payload) { dismiss() }
            saving = false 
        }
    }
}
