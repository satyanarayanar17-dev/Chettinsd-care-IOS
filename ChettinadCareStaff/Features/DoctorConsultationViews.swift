import SwiftUI
import ChettinadCore

struct PatientDossierView: View {
    @StateObject var viewModel: DoctorConsultationViewModel
    @State private var showConsultation = false
    @State private var careRefreshVersion = 0
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) var dismiss
    let patientName: String
    
    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView("Loading Dossier...")
                    .padding(.top, 40)
            } else if let error = viewModel.errorMessage {
                StitchErrorState(message: error) { Task { await viewModel.fetchPatientDossier() } }
                    .padding()
            } else if let bundle = viewModel.recordBundle {
                VStack(alignment: .leading, spacing: 20) {
                    // Patient Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(bundle.patient.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("MRN: \(bundle.patient.mrn)")
                                .font(Typography.bodyLarge)
                                .foregroundColor(.secondary)
                            Text("\(bundle.patient.dob) • \(bundle.patient.gender)")
                                .font(Typography.bodyLarge)
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
                    if let triage = bundle.triage.first(where: { $0.encounter_id == viewModel.encounterId }) {
                        StitchCard {
                        VStack(alignment: .leading, spacing: StitchSpacing.sm) {
                            Text("Current Triage")
                                .font(Typography.titleMedium)
                            if let d = triage.data {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: StitchSpacing.sm) {
                                    VitalCell(label: "Temp", value: d.temperature.map { String(format: "%.1f °C", $0) } ?? "—")
                                    VitalCell(label: "BP", value: "\(d.systolic.map(String.init) ?? "—")/\(d.diastolic.map(String.init) ?? "—")")
                                    VitalCell(label: "Pulse", value: d.pulse.map { "\($0) bpm" } ?? "—")
                                    VitalCell(label: "SpO2", value: d.spo2.map { "\($0)%" } ?? "—")
                                    VitalCell(label: "Weight", value: d.weight.map { "\($0) kg" } ?? "—")
                                    VitalCell(label: "BMI", value: d.bmi.map { String(format: "%.1f", $0) } ?? "—")
                                }
                                if let complaint = d.complaint {
                                    Text("Complaint: \(complaint)")
                                        .font(Typography.bodyLarge)
                                        .padding(.top, 4)
                                }
                            }
                        }
                    }
                    }
                    
                    // Start Consultation Button
                    Button(action: {
                        Task {
                            let opened: Bool
                            if viewModel.isFinalized { opened = true } else { opened = await viewModel.startConsultation() }
                            if opened {
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
                                Text(viewModel.isFinalized ? "Review signed consultation" : "Start or resume consultation")
                                    .fontWeight(.bold)
                            }
                        }
                        .buttonStyle(StitchPrimaryButtonStyle())
                    }
                    .disabled(viewModel.isSubmitting)
                    
                    PatientCarePlanMonitoringView(patientId: bundle.patient.id, role: "DOCTOR", refreshVersion: careRefreshVersion)
                        .padding(.vertical)

                    // Historical clinical records
                    if !bundle.encounters.isEmpty {
                        VStack(alignment: .leading, spacing: StitchSpacing.sm) {
                            Text("History")
                                .font(Typography.titleMedium)
                            ForEach(bundle.notes) { note in
                                DisclosureGroup("\(note.status) · \(note.author_name ?? note.author_id) · \(ISODate.display(note.updated_at ?? note.created_at)) · v\(note.__v)") {
                                    if let data = note.draft_content {
                                        Text(data.complaint ?? ""); Text(data.history ?? ""); Text(data.previous_history ?? ""); Text(data.examination ?? ""); Text(data.assessment ?? ""); Text(data.treatment ?? ""); Text(data.advice ?? "")
                                    }
                                }
                            }
                            ForEach(bundle.labs) { LabResultSummary(order: $0) }
                            ForEach(bundle.prescriptions) { prescription in
                                SignedPrescriptionView(prescription: prescription, patient: bundle.patient)
                            }
                        }
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Dossier")
        .navigationBarTitleDisplayMode(.inline)
        .refreshFromHospital {
            if !viewModel.isSubmitting { await viewModel.fetchPatientDossier(silent: viewModel.recordBundle != nil) }
        }
        .refreshable {
            await viewModel.fetchPatientDossier()
            careRefreshVersion += 1
        }
        .sheet(isPresented: $showConsultation, onDismiss: {
            // Only leave the dossier after a successful "Complete & Sign", not on Cancel.
            if viewModel.consultationCompleted { dismiss() }
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
                .font(Typography.titleMedium)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(StitchSpacing.sm)
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
    @State private var pendingLabTest: CataloguesResponse.Test?
    @State private var confirmingSign = false
    @State private var confirmingClose = false
    @State private var reviewingConflict = false
    
    var body: some View {
        NavigationView {
            Form {
                if let patient = viewModel.recordBundle?.patient {
                    Section("Patient and visit") {
                        Text(patient.name).font(.headline)
                        Text("MRN \(patient.mrn) · \(patient.dob) · \(patient.gender)")
                        Text("Visit \(viewModel.encounterId ?? "Unavailable")").font(.caption)
                        Text(patient.allergies?.isEmpty == false ? "Allergies: \(patient.allergies!)" : (patient.allergy_review_status == "NONE_REPORTED" ? "No allergies reported" : "Allergies not recorded"))
                            .foregroundStyle(patient.allergies?.isEmpty == false ? Color.chettinadError : Color.secondary)
                        if patient.allergy_reviewed_at == nil { Text("Allergy review is not recorded.").font(.caption) }
                    }
                }
                Section("Saved record") {
                    Text(viewModel.isFinalized ? "Signed consultation · version \(viewModel.noteVersion)" : "Draft · version \(viewModel.noteVersion)")
                    if let at = viewModel.lastSavedAt { Text("Last saved \(ISODate.display(at))").font(.caption) }
                    Text(viewModel.hasUnsavedChanges ? "Changes waiting to be saved" : "Saved changes are up to date")
                        .foregroundStyle(viewModel.hasUnsavedChanges ? Color.chettinadError : Color.secondary)
                    if let message = viewModel.recoveryMessage { Text(message).font(.caption) }
                    if viewModel.conflictingSavedDraft != nil {
                        Button("Review conflicting saved note") { reviewingConflict = true }
                    }
                    if !viewModel.isFinalized {
                        Button("Save draft") { Task { _ = await viewModel.saveDraft() } }
                            .disabled(viewModel.isSubmitting || viewModel.conflictingSavedDraft != nil)
                    } else {
                        TextField("Reason for amendment", text:$viewModel.amendReason,axis:.vertical)
                    }
                }
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
                    VStack(alignment:.leading,spacing:4) {
                        Text("Previous history").font(.caption).foregroundStyle(.secondary)
                        TextEditor(text:$viewModel.notePreviousHistory).frame(minHeight:80)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Assessment / Diagnosis").font(.caption).foregroundColor(.secondary)
                        TextEditor(text: $viewModel.noteAssessment)
                            .frame(height: 80)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Advice").font(.caption).foregroundColor(.secondary)
                        Text("Treatment").font(.caption).foregroundStyle(.secondary)
                        TextEditor(text: $viewModel.noteTreatment).frame(minHeight: 80)
                        TextEditor(text: $viewModel.noteAdvice)
                            .frame(height: 80)
                    }
                }
                
                ConsultationFollowUpSection(model: viewModel)
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
                        ForEach(Array(viewModel.medications.enumerated()), id: \.offset) { index, med in
                            VStack(alignment: .leading) {
                                Text(cat.drugs.first(where: { $0.id == med.drug_id })?.name ?? med.drug_id)
                                    .font(Typography.titleMedium)
                                Text("\(med.dose) • \(med.frequency) • \(med.duration)")
                                    .font(Typography.bodyLarge)
                                if let inst = med.instructions, !inst.isEmpty {
                                    Text(inst).font(.caption).foregroundColor(.secondary)
                                }
                                Button("Remove medication",role:.destructive) { viewModel.medications.remove(at:index) }
                            }
                        }
                        
                        Button("Add Medication") { showingAddMedication = true }
                    }
                    
                    if !viewModel.isFinalized { Section(header: Text("Order Labs")) {
                        ForEach(cat.tests) { test in
                            let alreadyOrdered = viewModel.orderedTestIds.contains(test.id)
                            let inFlight = viewModel.labOrdersInFlight.contains(test.id)
                            Button(action: { pendingLabTest = test }) {
                                HStack {
                                    Text(test.name)
                                    Spacer()
                                    if alreadyOrdered {
                                        Label("Ordered", systemImage: "checkmark.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    } else if inFlight {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "plus.circle")
                                    }
                                }
                            }
                            .foregroundColor(.primary)
                            .disabled(alreadyOrdered || inFlight)
                        }
                    } }
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
                    Button("Close") {
                        if viewModel.hasUnsavedChanges { confirmingClose = true } else { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.isFinalized ? "Sign amendment" : "Complete & Sign") { confirmingSign = true }
                        .disabled(!viewModel.canFinalize || (viewModel.isFinalized && viewModel.amendReason.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty))
                }
            }
            .task {
                viewModel.beginEditing()
                await viewModel.fetchCatalogues()
            }
            .onChange(of:viewModel.draftPayload) { _ in viewModel.draftChanged() }
            .onDisappear { viewModel.stopEditing() }
            .interactiveDismissDisabled(viewModel.hasUnsavedChanges || viewModel.isSubmitting)
            .confirmationDialog("Review and sign",isPresented:$confirmingSign,titleVisibility:.visible) {
                Button(viewModel.isFinalized ? "Sign amendment" : "Issue prescription and complete visit") {
                    Task {
                        let done = viewModel.isFinalized ? await viewModel.amendConsultation() : await viewModel.completeConsultation()
                        if done { dismiss() }
                    }
                }
                Button("Keep editing",role:.cancel) {}
            } message: {
                Text("\(viewModel.recordBundle?.patient.name ?? "Patient") · MRN \(viewModel.recordBundle?.patient.mrn ?? "Unavailable")\n\(viewModel.medications.count) medication(s). Confirm the patient, instructions and follow-up before signing.")
            }
            .confirmationDialog("Save your changes before closing",isPresented:$confirmingClose,titleVisibility:.visible) {
                if !viewModel.isFinalized { Button("Save draft and close") { Task { if await viewModel.saveDraft() { dismiss() } } } }
                Button("Keep unfinished draft on this device and close") { Task { if await viewModel.persistLocalDraft() { dismiss() } } }
                Button("Keep editing",role:.cancel) {}
            } message: { Text("An unfinished note must be saved before leaving this workspace.") }
            .sheet(isPresented:$reviewingConflict) {
                NavigationStack {
                    ScrollView {
                        VStack(alignment:.leading,spacing:16) {
                            Text("Your entered note").font(.headline)
                            ConsultationComparison(data: viewModel.draftPayload)
                            Divider()
                            Text("Latest saved note · version \(viewModel.conflictingNoteVersion ?? 0)").font(.headline)
                            if let data = viewModel.conflictingSavedDraft { ConsultationComparison(data: data) }
                            Button("Use latest saved note") { viewModel.useLatestSavedDraft(); reviewingConflict = false }
                            Button("Keep my note as a new version") { viewModel.keepMyDraftAfterReview(); reviewingConflict = false }
                            Text("Previous saved versions remain in the clinical history.").font(.caption)
                        }.padding()
                    }.navigationTitle("Review note conflict")
                    .toolbar { Button("Close") { reviewingConflict = false } }
                }
            }
            .confirmationDialog(
                "Order lab test?",
                isPresented: Binding(get: { pendingLabTest != nil }, set: { if !$0 { pendingLabTest = nil } }),
                titleVisibility: .visible,
                presenting: pendingLabTest
            ) { test in
                Button("Order \(test.name)") {
                    Task { await viewModel.orderLab(testId: test.id) }
                }
                Button("Cancel", role: .cancel) {}
            } message: { test in
                Text("This places a lab order for \(test.name) (\(test.code)) on this encounter.")
            }
            .sheet(isPresented: $showingAddMedication) {
                NavigationView {
                    Form {
                        if let cat = viewModel.catalogues {
                            Picker("Drug", selection: $newMedDrugId) {
                                Text("Select Drug").tag(String?.none)
                                ForEach(cat.drugs) { drug in
                                    Text("\(drug.name) · \(drug.strength) · \(drug.form) · \(drug.route)").tag(String?.some(drug.id))
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
