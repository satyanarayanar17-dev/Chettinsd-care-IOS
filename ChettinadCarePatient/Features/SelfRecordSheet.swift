import SwiftUI

struct SelfRecordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: CarePlanViewModel
    @State private var type = "GLUCOSE"
    @State private var timing = "FASTING"
    @State private var primary = ""
    @State private var secondary = ""
    @State private var activity = ""
    @State private var duration = ""
    @State private var observedAt = Date()
    @State private var note = ""
    @State private var saving = false
    private let types = ["GLUCOSE", "BLOOD_PRESSURE", "WEIGHT", "TEMPERATURE", "PULSE", "SPO2", "ACTIVITY"]
    private let timings = ["FASTING", "BEFORE_BREAKFAST", "AFTER_BREAKFAST", "BEFORE_LUNCH", "AFTER_LUNCH", "BEFORE_DINNER", "POST_DINNER", "BEDTIME", "RANDOM"]

    var body: some View {
        NavigationView {
            Form {
                Section("Record") {
                    Picker("Type", selection: $type) { ForEach(types, id: \.self) { Text($0.replacingOccurrences(of: "_", with: " ").capitalized).tag($0) } }
                    if type == "GLUCOSE" { Picker("Timing", selection: $timing) { ForEach(timings, id: \.self) { Text($0.replacingOccurrences(of: "_", with: " ").capitalized).tag($0) } } }
                    if type == "ACTIVITY" {
                        TextField("Activity", text: $activity)
                        TextField("Duration in minutes", text: $duration).keyboardType(.numberPad)
                    } else {
                        TextField(type == "BLOOD_PRESSURE" ? "Systolic" : "Value", text: $primary).keyboardType(.decimalPad)
                        if type == "BLOOD_PRESSURE" { TextField("Diastolic", text: $secondary).keyboardType(.decimalPad) }
                        LabeledContent("Unit", value: unit)
                    }
                    DatePicker("Recorded at", selection: $observedAt)
                    TextField("Optional note", text: $note, axis: .vertical)
                }
                Section { Text("This is stored as Patient self-recorded. It does not change your diagnosis or treatment.").font(.caption).foregroundColor(.secondary) }
            }
            .navigationTitle("Add Record")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(saving ? "Saving…" : "Save") { save() }.disabled(!valid || saving) }
            }
        }
    }

    private var unit: String { ["GLUCOSE":"mg/dL", "BLOOD_PRESSURE":"mmHg", "WEIGHT":"kg", "TEMPERATURE":"°C", "PULSE":"bpm", "SPO2":"%"][type] ?? "" }
    private var valid: Bool { type == "ACTIVITY" ? !activity.trimmingCharacters(in: .whitespaces).isEmpty && Int(duration) != nil : Double(primary) != nil && (type != "BLOOD_PRESSURE" || Double(secondary) != nil) }
    private func save() {
        saving = true
        let payload = PatientSelfRecordPayload(record_type: type, timing_context: type == "GLUCOSE" ? timing : nil, numeric_value: type == "ACTIVITY" ? nil : Double(primary), secondary_numeric_value: type == "BLOOD_PRESSURE" ? Double(secondary) : nil, unit: type == "ACTIVITY" ? nil : unit, activity_name: type == "ACTIVITY" ? activity : nil, duration_minutes: type == "ACTIVITY" ? Int(duration) : nil, observed_at: ISO8601DateFormatter().string(from: observedAt), patient_note: note.isEmpty ? nil : note)
        Task { if await viewModel.addSelfRecord(payload) { dismiss() }; saving = false }
    }
}
