import SwiftUI
import ChettinadCore

struct PatientDossierView: View {
    @StateObject var viewModel: DoctorConsultationViewModel
    @State private var showConsultation = false
    @Environment(\.dismiss) var dismiss
    let patientName: String
    
    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView("Loading Dossier...")
                    .padding(.top, 40)
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.orange)
                    Text(error)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else if let bundle = viewModel.recordBundle {
                VStack(alignment: .leading, spacing: 20) {
                    PatientCarePlanMonitoringView(patientId: bundle.patient.id, role: "DOCTOR")
                        .padding(.vertical)
                    
                    // Patient Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(bundle.patient.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("MRN: \(bundle.patient.mrn)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("\(bundle.patient.dob) • \(bundle.patient.gender)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            if let allergies = bundle.patient.allergies, !allergies.isEmpty {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text(allergies)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                }
                            }
                        }
                        Spacer()
                        Image(systemName: "person.text.rectangle")
                            .font(.largeTitle)
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Current Encounter Triage
                    if let triage = bundle.triage.last(where: { $0.encounter_id == viewModel.encounterId }) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Current Triage")
                                .font(.headline)
                            if let d = triage.data {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                                    VitalCell(label: "Temp", value: d.temperature.map { String(format: "%.1f °C", $0) } ?? "—")
                                    VitalCell(label: "BP", value: "\(d.systolic ?? 0)/\(d.diastolic ?? 0)")
                                    VitalCell(label: "Pulse", value: d.pulse.map { "\($0) bpm" } ?? "—")
                                    VitalCell(label: "SpO2", value: d.spo2.map { "\($0)%" } ?? "—")
                                    VitalCell(label: "Weight", value: d.weight.map { "\($0) kg" } ?? "—")
                                    VitalCell(label: "BMI", value: d.bmi.map { String(format: "%.1f", $0) } ?? "—")
                                }
                                if let complaint = d.complaint {
                                    Text("Complaint: \(complaint)")
                                        .font(.subheadline)
                                        .padding(.top, 4)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                    }
                    
                    // Start Consultation Button
                    Button(action: {
                        Task {
                            if await viewModel.startConsultation() {
                                showConsultation = true
                            }
                        }
                    }) {
                        HStack {
                            if viewModel.isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Image(systemName: "stethoscope")
                                Text("Start Consultation")
                                    .fontWeight(.bold)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isSubmitting)
                    
                    // Historical Summary
                    if !bundle.encounters.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("History")
                                .font(.headline)
                            Text("\(bundle.encounters.count) encounters • \(bundle.notes.count) notes • \(bundle.prescriptions.count) prescriptions • \(bundle.labs.count) labs")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Dossier")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.fetchPatientDossier()
        }
        .sheet(isPresented: $showConsultation, onDismiss: {
            dismiss()
        }) {
            ConsultationWorkspaceView(viewModel: viewModel)
        }
    }
}

struct VitalCell: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(Color(.tertiarySystemBackground))
        .cornerRadius(8)
    }
}

struct ConsultationWorkspaceView: View {
    @ObservedObject var viewModel: DoctorConsultationViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var showingAddMedication = false
    @State private var newMedDrugId: String? = nil
    @State private var newMedDose = ""
    @State private var newMedFreq = ""
    @State private var newMedDuration = ""
    @State private var newMedInstr = ""
    
    var body: some View {
        NavigationView {
            Form {
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }
                
                Section(header: Text("Clinical Note")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("History").font(.caption).foregroundColor(.secondary)
                        TextEditor(text: $viewModel.noteHistory).frame(height: 80)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Chief Complaint").font(.caption).foregroundColor(.secondary)
                        TextEditor(text: $viewModel.noteComplaint)
                            .frame(height: 80)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Examination Findings").font(.caption).foregroundColor(.secondary)
                        TextEditor(text: $viewModel.noteExamination)
                            .frame(height: 80)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Assessment / Diagnosis").font(.caption).foregroundColor(.secondary)
                        TextEditor(text: $viewModel.noteAssessment)
                            .frame(height: 80)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Advice / Follow-up").font(.caption).foregroundColor(.secondary)
                        TextEditor(text: $viewModel.noteAdvice)
                            .frame(height: 80)
                    }
                }
                
                if let cat = viewModel.catalogues {
                    Section(header: Text("Diagnoses (ICD-10)")) {
                        ForEach(cat.diagnoses) { dx in
                            Toggle(dx.name, isOn: Binding(
                                get: { viewModel.selectedDiagnoses.contains(dx.id) },
                                set: { isOn in
                                    if isOn { viewModel.selectedDiagnoses.insert(dx.id) }
                                    else { viewModel.selectedDiagnoses.remove(dx.id) }
                                }
                            ))
                        }
                    }
                    
                    Section(header: Text("Prescription")) {
                        ForEach(viewModel.medications, id: \.drug_id) { med in
                            VStack(alignment: .leading) {
                                Text(cat.drugs.first(where: { $0.id == med.drug_id })?.name ?? med.drug_id)
                                    .font(.headline)
                                Text("\(med.dose) • \(med.frequency) • \(med.duration)")
                                    .font(.subheadline)
                                if let inst = med.instructions, !inst.isEmpty {
                                    Text(inst).font(.caption).foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        Button("Add Medication") { showingAddMedication = true }
                    }
                    
                    Section(header: Text("Order Labs")) {
                        ForEach(cat.tests) { test in
                            Button(action: {
                                Task { await viewModel.orderLab(testId: test.id) }
                            }) {
                                HStack {
                                    Text(test.name)
                                    Spacer()
                                    Image(systemName: "plus.circle")
                                }
                            }
                            .foregroundColor(.primary)
                        }
                    }
                } else {
                    Section {
                        ProgressView("Loading Catalogues...")
                    }
                }
            }
            .navigationTitle("Consultation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Complete & Sign") {
                        Task {
                            if await viewModel.completeConsultation() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isSubmitting || viewModel.noteHistory.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.noteExamination.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.noteAssessment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.noteAdvice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.selectedDiagnoses.isEmpty)
                }
            }
            .task {
                await viewModel.fetchCatalogues()
            }
            .sheet(isPresented: $showingAddMedication) {
                NavigationView {
                    Form {
                        if let cat = viewModel.catalogues {
                            Picker("Drug", selection: $newMedDrugId) {
                                Text("Select Drug").tag(String?.none)
                                ForEach(cat.drugs) { drug in
                                    Text("\(drug.name) (\(drug.strength))").tag(String?.some(drug.id))
                                }
                            }
                            TextField("Dose (e.g. 1 tab)", text: $newMedDose)
                            TextField("Frequency (e.g. BID)", text: $newMedFreq)
                            TextField("Duration (e.g. 5 days)", text: $newMedDuration)
                            TextField("Instructions", text: $newMedInstr)
                        }
                    }
                    .navigationTitle("New Prescription")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showingAddMedication = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Add") {
                                if let id = newMedDrugId {
                                    viewModel.medications.append(PrescriptionDrug(drug_id: id, dose: newMedDose, frequency: newMedFreq, duration: newMedDuration, instructions: newMedInstr.isEmpty ? nil : newMedInstr))
                                }
                                showingAddMedication = false
                            }
                            .disabled(newMedDrugId == nil || newMedDose.isEmpty || newMedFreq.isEmpty || newMedDuration.isEmpty)
                        }
                    }
                }
            }
        }
    }
}
