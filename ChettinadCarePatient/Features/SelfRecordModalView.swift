import SwiftUI
import ChettinadCore

struct CreateSelfRecordEndpoint: APIEndpoint {
    typealias Response = EmptyResponse
    let patientId: String
    let payload: SelfRecordPayload
    var path: String { "/api/v1/opd/patient-self-records/\(patientId)" }
    var method: HTTPMethod { .post }
    var body: Data? { try? JSONEncoder().encode(payload) }
}

struct SelfRecordPayload: Codable {
    let record_type: String
    let timing_context: String?
    let primary_value: Double?
    let secondary_value: Double?
    let activity_name: String?
    let duration_minutes: Int?
    let note: String?
}

struct EmptyResponse: Codable {}

struct SelfRecordModalView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: PatientViewModel
    
    @State private var type = "GLUCOSE"
    @State private var timing = "FASTING"
    @State private var primary = ""
    @State private var secondary = ""
    @State private var activity = ""
    @State private var duration = ""
    @State private var note = ""
    @State private var isSubmitting = false
    
    let types = ["GLUCOSE", "BLOOD_PRESSURE", "WEIGHT", "TEMPERATURE", "PULSE", "SPO2", "ACTIVITY"]
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Picker("Type", selection: $type) {
                        ForEach(types, id: \.self) { Text($0.replacingOccurrences(of: "_", with: " ").capitalized) }
                    }
                    if type == "GLUCOSE" {
                        Picker("Timing", selection: $timing) {
                            Text("Fasting").tag("FASTING")
                            Text("Post-Prandial").tag("POST_PRANDIAL")
                            Text("Random").tag("RANDOM")
                        }
                        TextField("Value (mg/dL)", text: $primary).keyboardType(.decimalPad)
                    } else if type == "BLOOD_PRESSURE" {
                        TextField("Systolic (mmHg)", text: $primary).keyboardType(.decimalPad)
                        TextField("Diastolic (mmHg)", text: $secondary).keyboardType(.decimalPad)
                    } else if type == "ACTIVITY" {
                        TextField("Activity Name", text: $activity)
                        TextField("Duration (mins)", text: $duration).keyboardType(.numberPad)
                    } else {
                        let unit = type == "WEIGHT" ? "kg" : (type == "TEMPERATURE" ? "°C" : (type == "PULSE" ? "bpm" : "%"))
                        TextField("Value (\(unit))", text: $primary).keyboardType(.decimalPad)
                    }
                    TextField("Optional Note", text: $note)
                }
            }
            .navigationTitle("Add Record")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        isSubmitting = true
                        Task {
                            let patientId = viewModel.recordBundle?.patient.id ?? ""
                            let payload = SelfRecordPayload(
                                record_type: type,
                                timing_context: type == "GLUCOSE" ? timing : nil,
                                primary_value: Double(primary),
                                secondary_value: Double(secondary),
                                activity_name: type == "ACTIVITY" ? activity : nil,
                                duration_minutes: Int(duration),
                                note: note.isEmpty ? nil : note
                            )
                            do {
                                let apiClient = APIClient()
                                let _: EmptyResponse = try await apiClient.execute(endpoint: CreateSelfRecordEndpoint(patientId: patientId, payload: payload))
                                await viewModel.fetchCarePlan() // refresh
                                dismiss()
                            } catch {
                                viewModel.errorMessage = error.localizedDescription
                                isSubmitting = false
                            }
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
        }
    }
}
