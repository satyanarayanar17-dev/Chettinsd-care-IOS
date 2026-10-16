import SwiftUI
import ChettinadCore

struct TriageFormView: View {
    @StateObject var viewModel: TriageFormViewModel
    @Environment(\.dismiss) var dismiss
    let patientId: String
    let patientName: String
    
    @State private var initialSnapshot: [String]?
    @State private var confirmingClose = false
    private var dirty: Bool { initialSnapshot.map { $0 != viewModel.editableSnapshot } ?? false }
    var body: some View {
        Form {
            if let patient = viewModel.patient {
                Section("Patient and visit") {
                    Text(patient.name).font(.headline)
                    Text("MRN \(patient.mrn) · \(patient.dob) · \(patient.gender)")
                    Text("Visit \(viewModel.encounterId)").font(.caption)
                }
                Section("Allergy review") {
                    Text(viewModel.allergies.isEmpty ? (viewModel.allergyStatus == "NONE_REPORTED" ? "No allergies reported" : "Allergies not recorded") : viewModel.allergies)
                    Toggle("I reviewed allergies with the patient",isOn:$viewModel.allergyReviewConfirmed)
                    if viewModel.allergyReviewConfirmed {
                        Picker("Record status",selection:$viewModel.allergyStatus) {
                            Text("Unknown / not recorded").tag("UNKNOWN")
                            Text("No allergies reported").tag("NONE_REPORTED")
                            Text("Allergies recorded").tag("RECORDED")
                        }
                        TextField("Recorded allergies",text:$viewModel.allergies,axis:.vertical)
                        TextField("Reason for changing this record",text:$viewModel.allergyChangeReason,axis:.vertical)
                    }
                    Text("Existing allergy information stays unchanged until you confirm a review.").font(.caption)
                }
            }
            Section("Care Plan") {
                NavigationLink("View adherence and readings") {
                    ScrollView {
                        PatientCarePlanMonitoringView(patientId: patientId, role: "NURSE")
                            .padding(.vertical)
                    }
                    .navigationTitle("Patient Care Plan")
                }
            }
            if let error = viewModel.errorMessage {
                Section {
                    StitchErrorState(message: error)
                }
            }
            
            Section(header: Text("Vitals")) {
                HStack {
                    Text("Temp (°C)")
                    Spacer()
                    TextField("e.g. 37.0", text: $viewModel.temperature)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("Blood Pressure")
                    Spacer()
                    TextField("Sys", text: $viewModel.systolic)
                        .keyboardType(.numberPad)
                        .frame(width: 50)
                        .multilineTextAlignment(.trailing)
                    Text("/")
                    TextField("Dia", text: $viewModel.diastolic)
                        .keyboardType(.numberPad)
                        .frame(width: 50)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("Pulse (bpm)")
                    Spacer()
                    TextField("e.g. 80", text: $viewModel.pulse)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("SpO2 (%)")
                    Spacer()
                    TextField("e.g. 98", text: $viewModel.spo2)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("Weight (kg)")
                    Spacer()
                    TextField("e.g. 70.5", text: $viewModel.weight)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                }
            }
            
            Section(header: Text("Additional measurements")) {
                TextField("Height (cm)", text: $viewModel.height).keyboardType(.decimalPad)
                TextField("Pain (0–10)", text: $viewModel.pain).keyboardType(.numberPad)
                TextField("Nurse notes", text: $viewModel.notes)
                Picker("Priority", selection: $viewModel.priority) {
                    Text("Routine").tag(0)
                    Text("Priority").tag(1)
                    Text("Urgent").tag(2)
                }
            }
            Section(header: Text("Complaint")) {
                TextEditor(text: $viewModel.complaint)
                    .frame(height: 80)
            }
            if viewModel.hasPreviousTriage {
                Section("Amendment") { TextField("Reason for correcting triage",text:$viewModel.amendmentReason,axis:.vertical) }
            }
        }
        .navigationTitle("Triage: \(patientName)")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .interactiveDismissDisabled(dirty || viewModel.isSubmitting)
        .confirmationDialog("Discard entered triage?",isPresented:$confirmingClose,titleVisibility:.visible) {
            Button("Discard entered changes and close",role:.destructive) { dismiss() }
            Button("Keep entering triage",role:.cancel) {}
        } message: { Text("These changes have not been saved. Confirm the patient and submit triage to hand the visit to the doctor.") }
        .toolbar {
            ToolbarItem(placement:.cancellationAction) { Button("Back") { if dirty { confirmingClose = true } else { dismiss() } }.disabled(viewModel.isSubmitting) }
            ToolbarItem(placement: .confirmationAction) {
                Button("Submit") {
                    Task {
                        if await viewModel.submitTriage() {
                            dismiss()
                        }
                    }
                }
                .disabled(viewModel.isSubmitting || viewModel.isLoading || viewModel.validationError != nil)
            }
        }
        .task {
            if await viewModel.startTriage() { initialSnapshot = viewModel.editableSnapshot }
        }
        .overlay {
            if viewModel.isLoading || viewModel.isSubmitting {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.1))
            }
        }
    }
}
