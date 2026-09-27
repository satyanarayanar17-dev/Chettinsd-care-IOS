import SwiftUI
import ChettinadCore
import UniformTypeIdentifiers
import QuickLook
struct PatientDashboardView: View {
    @EnvironmentObject var viewModel: PatientViewModel
    let onAppointments: () -> Void
    let onRecords: () -> Void
    let onCarePlan: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            AppHeader(title: "Chettinad Care")
            
            ScrollView {
                if viewModel.isLoading {
                    ProgressView("Loading Dashboard...")
                        .padding(StitchSpacing.xxl)
                } else if let error = viewModel.errorMessage, viewModel.recordBundle == nil {
                    StitchErrorState(message: error) {
                        Task { await viewModel.fetchRecords() }
                    }
                    .padding(StitchSpacing.lg)
                } else if let bundle = viewModel.recordBundle {
                    VStack(alignment: .leading, spacing: StitchSpacing.xl) {
                        
                        // Greeting
                        VStack(alignment: .leading, spacing: StitchSpacing.xs) {
                            Text("Welcome,")
                                .textStyle(Typography.titleMedium, color: .chettinadSecondary)
                            Text(bundle.patient.name)
                                .textStyle(Typography.headlineLarge, color: .chettinadPrimary)
                        }
                        .padding(.horizontal, StitchSpacing.lg)
                        .padding(.top, StitchSpacing.lg)
                        
                        // Next Appointment
                        if let nextApt = viewModel.appointments.filter({ !["COMPLETED", "CANCELLED", "NO_SHOW"].contains($0.status) && (ISODate.parse($0.scheduled_at).map { d in d >= Date() } ?? false) }).sorted(by: { $0.scheduled_at < $1.scheduled_at }).first {
                            VStack(alignment: .leading, spacing: StitchSpacing.sm) {
                                HStack {
                                    Text("Next Appointment").font(Typography.titleMedium).foregroundStyle(Color.chettinadTextPrimary)
                                    Spacer()
                                    Button("View all", action: onAppointments).buttonStyle(StitchCompactButtonStyle())
                                }
                                .padding(.horizontal, StitchSpacing.lg)
                                
                                StitchCard {
                                    VStack(alignment: .leading, spacing: StitchSpacing.md) {
                                        Text(nextApt.doctor_name ?? "Obstetrics & Gynaecology").font(Typography.titleMedium).foregroundStyle(Color.chettinadPrimary)
                                        Text(ISODate.display(nextApt.scheduled_at)).font(Typography.bodyLarge).foregroundStyle(Color.chettinadTextSecondary)
                                        StitchStatusChip(status: nextApt.status)
                                    }
                                }
                                .padding(.horizontal, StitchSpacing.lg)
                            }
                        }
                        
                        // Today's Care Plan
                        VStack(alignment: .leading, spacing: StitchSpacing.sm) {
                            HStack {
                                Text("Today's Care Plan").font(Typography.titleMedium).foregroundStyle(Color.chettinadTextPrimary)
                                Spacer()
                                Button("Open", action: onCarePlan).buttonStyle(StitchCompactButtonStyle())
                            }
                            .padding(.horizontal, StitchSpacing.lg)
                            
                            StitchCard {
                                VStack(alignment: .leading, spacing: StitchSpacing.md) {
                                    if viewModel.todayCareTasks.isEmpty {
                                        Text("No tasks scheduled for today.").font(Typography.bodyLarge).foregroundStyle(Color.chettinadTextSecondary)
                                    } else {
                                        let completed = viewModel.todayCareTasks.filter { $0.status == .COMPLETED || $0.status == .SKIPPED || $0.status == .MISSED }.count
                                        Text("(completed) of (viewModel.todayCareTasks.count) tasks completed").font(Typography.titleMedium).foregroundStyle(Color.chettinadPrimary)
                                        ProgressView(value: Double(completed), total: Double(max(viewModel.todayCareTasks.count, 1)))
                                            .tint(.chettinadPrimary)
                                        
                                        if let nextDue = viewModel.todayCareTasks.first(where: { $0.status == .DUE || $0.status == .UPCOMING }) {
                                            Text("Next due: (nextDue.title) at (nextDue.scheduled_time)").font(Typography.bodyMedium).foregroundStyle(Color.chettinadTextSecondary)
                                        } else if completed == viewModel.todayCareTasks.count {
                                            Text("All caught up for today!").font(Typography.bodyMedium).foregroundStyle(Color.chettinadSuccess)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, StitchSpacing.lg)
                        }
                        
                        // Quick Actions
                        VStack(alignment: .leading, spacing: StitchSpacing.sm) {
                            Text("Quick Actions").font(Typography.titleMedium).foregroundStyle(Color.chettinadTextPrimary).padding(.horizontal, StitchSpacing.lg)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: StitchSpacing.lg) {
                                Button(action: onAppointments) {
                                    VStack(spacing: StitchSpacing.sm) {
                                        Image(systemName: "calendar.badge.plus").font(.system(size: 24, weight: .medium))
                                        Text("Book").font(Typography.labelLarge)
                                    }
                                    .frame(maxWidth: .infinity).padding(StitchSpacing.lg)
                                    .background(Color.chettinadPrimary.opacity(0.1))
                                    .foregroundStyle(Color.chettinadPrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }.buttonStyle(.plain)
                                
                                Button(action: onRecords) {
                                    VStack(spacing: StitchSpacing.sm) {
                                        Image(systemName: "doc.badge.plus").font(.system(size: 24, weight: .medium))
                                        Text("Upload").font(Typography.labelLarge)
                                    }
                                    .frame(maxWidth: .infinity).padding(StitchSpacing.lg)
                                    .background(Color.chettinadPrimary.opacity(0.1))
                                    .foregroundStyle(Color.chettinadPrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }.buttonStyle(.plain)
                            }.padding(.horizontal, StitchSpacing.lg)
                        }
                        
                        // Recent
                        VStack(alignment: .leading, spacing: StitchSpacing.sm) {
                            Text("Recent").font(Typography.titleMedium).foregroundStyle(Color.chettinadTextPrimary).padding(.horizontal, StitchSpacing.lg)
                            if let rx = bundle.prescriptions.first {
                                StitchCard {
                                    HStack(spacing: StitchSpacing.md) {
                                        Image(systemName: "pills.fill").font(.system(size: 24)).foregroundColor(.purple)
                                        VStack(alignment: .leading, spacing: StitchSpacing.xs) {
                                            Text("Latest Prescription").font(Typography.titleSmall).foregroundStyle(Color.chettinadTextPrimary)
                                            Text(String(rx.created_at.prefix(10))).font(Typography.bodyMedium).foregroundStyle(Color.chettinadTextSecondary)
                                        }
                                        Spacer()
                                    }
                                }.padding(.horizontal, StitchSpacing.lg)
                            }
                            if let doc = viewModel.documents.first {
                                StitchCard {
                                    HStack(spacing: StitchSpacing.md) {
                                        Image(systemName: "doc.text.fill").font(.system(size: 24)).foregroundColor(.blue)
                                        VStack(alignment: .leading, spacing: StitchSpacing.xs) {
                                            Text("Latest Upload").font(Typography.titleSmall).foregroundStyle(Color.chettinadTextPrimary)
                                            Text(doc.title).font(Typography.bodyMedium).foregroundStyle(Color.chettinadTextSecondary)
                                        }
                                        Spacer()
                                    }
                                }.padding(.horizontal, StitchSpacing.lg)
                            }
                        }
                        .padding(.bottom, StitchSpacing.xxl)
                    }
                }
            }
            .background(Color.chettinadBackground)
            .refreshable {
                await viewModel.fetchRecords()
            }
        }
    }
}

struct PatientRecordsView: View {
    @EnvironmentObject var viewModel: PatientViewModel
    @State private var importingDocument = false
    @State private var previewURL: URL?
    @State private var uploadURL: URL?
    @State private var lastPreviewURL: URL?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppHeader(title: "Medical Records")
            
                ScrollView {
                    if viewModel.isLoading {
                        ProgressView()
                            .padding(StitchSpacing.xxl)
                    } else if let bundle = viewModel.recordBundle {
                        VStack(alignment: .leading, spacing: StitchSpacing.xl) {
                        
                            // Header
                            VStack(alignment: .leading, spacing: StitchSpacing.xs) {
                                Text(bundle.patient.name)
                                    .textStyle(Typography.titleLarge, color: .chettinadPrimary)
                                Text("MRN: \(bundle.patient.mrn) • \(bundle.patient.gender)")
                                    .textStyle(Typography.bodyMedium, color: .chettinadSecondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.surfaceContainerLowest)
                            .padding(.top, StitchSpacing.lg)
                        
                            // Sections
                            VStack(alignment: .leading, spacing: StitchSpacing.xl) {
                                if let journey = bundle.journey, !journey.isEmpty {
                                    SectionView(title: "My Journey") {
                                        ForEach(journey) { event in
                                            StitchCard {
                                                VStack(alignment: .leading, spacing: StitchSpacing.xs) {
                                                    Text(event.code.replacingOccurrences(of: "_", with: " "))
                                                        .font(Typography.titleMedium)
                                                    Text(ISODate.display(event.occurred_at, dateStyle: .medium, timeStyle: .short))
                                                        .font(Typography.bodyMedium)
                                                        .foregroundStyle(Color.chettinadTextSecondary)
                                                    if let actor = event.actor_name {
                                                        Text("By: \(actor)")
                                                            .font(Typography.bodyMedium)
                                                            .foregroundStyle(Color.chettinadTextSecondary)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                SectionView(title: "My documents") {
                                    Button { importingDocument = true } label: { Label("Upload PDF or image", systemImage: "square.and.arrow.up") }.buttonStyle(StitchPrimaryButtonStyle())
                                    if viewModel.documents.isEmpty {
                                        StitchEmptyState(icon: "doc.text", title: "No Documents", message: "Your uploaded reports, scans and PDFs will appear here.")
                                    } else {
                                        ForEach(viewModel.documents) { document in
                                            StitchCard {
                                                VStack(alignment: .leading, spacing: 10) {
                                                    Button { Task { previewURL = try? await viewModel.apiClient.downloadPatientDocument(document) } } label: {
                                                        HStack { Image(systemName: document.mime_type == "application/pdf" ? "doc.richtext" : "photo"); VStack(alignment: .leading) { Text(document.title).font(Typography.titleMedium); Text("\(document.document_type.replacingOccurrences(of: "_", with: " ").capitalized) · \(document.clinical_date) · Patient uploaded").font(Typography.bodyMedium).foregroundStyle(Color.chettinadTextSecondary) }; Spacer(); Image(systemName: "eye") }
                                                    }.buttonStyle(.plain)
                                                    Menu {
                                                        if document.appointment_id != nil { Button("Remove appointment attachment", role: .destructive) { Task { _ = await viewModel.linkDocument(document, to: nil) } } }
                                                        ForEach(viewModel.appointments) { appointment in
                                                            Button("\(ISODate.display(appointment.scheduled_at, dateStyle: .medium, timeStyle: .none)) · \(appointment.doctor_name ?? "OBST Doctor")") { Task { _ = await viewModel.linkDocument(document, to: appointment.id) } }
                                                        }
                                                    } label: {
                                                        Label(document.appointment_id == nil ? "Attach to appointment" : "Change appointment attachment", systemImage: "paperclip")
                                                            .font(Typography.bodyMedium)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            
                                if !bundle.notes.isEmpty {
                                    SectionView(title: "Clinical Notes") {
                                        ForEach(bundle.notes) { note in
                                            NavigationLink(destination: NoteDetailView(note: note)) {
                                                StitchCard {
                                                    VStack(alignment: .leading, spacing: StitchSpacing.xs) {
                                                        Text(note.author_name ?? "Doctor Note")
                                                            .textStyle(Typography.titleMedium, color: .chettinadTextPrimary)
                                                        Text(String(note.created_at.prefix(10)))
                                                            .textStyle(Typography.bodySmall, color: .chettinadTextSecondary)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            
                                if !bundle.prescriptions.isEmpty {
                                    SectionView(title: "Prescriptions") {
                                        ForEach(bundle.prescriptions) { rx in
                                            NavigationLink(destination: PrescriptionDetailView(prescription: rx)) {
                                                StitchCard {
                                                    VStack(alignment: .leading, spacing: StitchSpacing.xs) {
                                                        Text(rx.doctor_name ?? "Prescription")
                                                            .textStyle(Typography.titleMedium, color: .chettinadTextPrimary)
                                                        Text(String(rx.created_at.prefix(10)))
                                                            .textStyle(Typography.bodySmall, color: .chettinadTextSecondary)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            
                                if !bundle.labs.isEmpty {
                                    SectionView(title: "Lab Orders") {
                                        ForEach(bundle.labs) { lab in
                                            StitchCard {
                                                VStack(alignment: .leading, spacing: StitchSpacing.sm) {
                                                    HStack {
                                                        Text(lab.name ?? lab.code ?? "Lab Test")
                                                            .textStyle(Typography.titleMedium, color: .chettinadTextPrimary)
                                                        Spacer()
                                                        StitchStatusChip(status: lab.status)
                                                    }
                                                    if let result = lab.result {
                                                        Text("Result: \(result)")
                                                            .textStyle(Typography.bodyMedium, color: .chettinadPrimary)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            
                                if !bundle.triage.isEmpty {
                                    SectionView(title: "Latest Triage") {
                                        if let tr = bundle.triage.first {
                                            StitchCard {
                                                VStack(alignment: .leading, spacing: StitchSpacing.sm) {
                                                    Text("Triage by \(tr.nurse_id ?? "Nurse")")
                                                        .textStyle(Typography.titleMedium, color: .chettinadTextPrimary)
                                                
                                                    if let d = tr.data {
                                                        HStack(spacing: StitchSpacing.lg) {
                                                            if let t = d.temperature { Text("Temp: \(String(format: "%.1f", t))") }
                                                            if let s = d.systolic, let dia = d.diastolic { Text("BP: \(s)/\(dia)") }
                                                        }
                                                        .textStyle(Typography.bodyMedium, color: .chettinadSecondary)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, StitchSpacing.lg)
                            .padding(.bottom, StitchSpacing.xl)
                        }
                    }
                }
                .background(Color.chettinadBackground)
                .refreshable {
                    await viewModel.fetchRecords()
                }
                .fileImporter(isPresented: $importingDocument, allowedContentTypes: [.pdf, .jpeg, .png], allowsMultipleSelection: false) { result in
                    guard case .success(let urls) = result, let url = urls.first else { return }
                    uploadURL = url
                }
                .sheet(isPresented: Binding(get: { uploadURL != nil }, set: { if !$0 { uploadURL = nil } })) { if let uploadURL { DocumentUploadSheet(fileURL: uploadURL).environmentObject(viewModel) } }
                .quickLookPreview($previewURL)
                .onChange(of: previewURL) { newValue in
                    // Delete the downloaded copy of the document once the preview is dismissed.
                    if let old = lastPreviewURL, old != newValue { try? FileManager.default.removeItem(at: old) }
                    lastPreviewURL = newValue
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct DocumentUploadSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: PatientViewModel
    let fileURL: URL
    @State private var type = "OTHER_MEDICAL_RECORD"
    @State private var title = ""
    @State private var clinicalDate = Date()
    @State private var appointmentId = ""
    @State private var note = ""
    @State private var saving = false
    var body: some View {
        NavigationView { Form {
            if let error = viewModel.errorMessage { Section { Text(error).foregroundColor(.chettinadError) } }
            Section("File") { Text(fileURL.lastPathComponent); TextField("Title", text: $title); Picker("Document type", selection: $type) { ForEach(["LAB_REPORT", "SCAN", "PRESCRIPTION", "DISCHARGE_SUMMARY", "REFERRAL", "OTHER_MEDICAL_RECORD"], id: \.self) { Text($0.replacingOccurrences(of: "_", with: " ").capitalized) } }; DatePicker("Report date", selection: $clinicalDate, in: ...Date(), displayedComponents: .date) }
            Section("Visit association") { Picker("Appointment", selection: $appointmentId) { Text("No appointment").tag(""); ForEach(viewModel.appointments) { Text("\(ISODate.display($0.scheduled_at, dateStyle: .medium, timeStyle: .none)) · \($0.doctor_name ?? "OG Doctor")").tag($0.id) } }; TextField("Optional patient note", text: $note, axis: .vertical) }
        }.navigationTitle("Upload document").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button(saving ? "Uploading…" : "Upload") { saving = true; let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"; Task { if await viewModel.uploadDocument(fileURL: fileURL, title: title, documentType: type, clinicalDate: formatter.string(from: clinicalDate), appointmentId: appointmentId.isEmpty ? nil : appointmentId, note: note.isEmpty ? nil : note) { dismiss() }; saving = false } }.disabled(saving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } } }
        .onAppear { if viewModel.recordBundle != nil { viewModel.errorMessage = nil } }
    }
}

struct SectionView<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: StitchSpacing.md) {
            Text(title)
                .textStyle(Typography.titleMedium, color: .chettinadPrimary)
            content
        }
    }
}

struct NoteDetailView: View {
    let note: Note
    var body: some View {
        List {
            Section(header: Text("Details")) {
                InfoRow(title: "Author", value: note.author_name ?? note.author_id)
                InfoRow(title: "Date", value: String(note.created_at.prefix(10)))
                InfoRow(title: "Status", value: note.status)
            }
            
            if let content = note.draft_content {
                if let complaint = content.complaint {
                    Section(header: Text("Chief Complaint")) {
                        Text(complaint)
                    }
                }
                if let examination = content.examination {
                    Section(header: Text("Examination")) {
                        Text(examination)
                    }
                }
                if let assessment = content.assessment {
                    Section(header: Text("Assessment")) {
                        Text(assessment)
                    }
                }
                if let diagnoses = content.diagnoses, !diagnoses.isEmpty {
                    Section(header: Text("Diagnoses")) {
                        ForEach(diagnoses, id: \.id) { d in
                            Text(d.name)
                        }
                    }
                }
                if let advice = content.advice {
                    Section(header: Text("Advice")) {
                        Text(advice)
                    }
                }
            }
        }
        .navigationTitle("Note Details")
    }
}

struct PrescriptionDetailView: View {
    let prescription: Prescription
    var body: some View {
        List {
            Section(header: Text("Details")) {
                InfoRow(title: "Doctor", value: prescription.doctor_name ?? prescription.authorizing_user_id)
                InfoRow(title: "Date", value: String(prescription.created_at.prefix(10)))
            }
            
            if let content = prescription.rx_content {
                if let meds = content.medications, !meds.isEmpty {
                    Section(header: Text("Medications")) {
                        ForEach(meds, id: \.drug_id) { med in
                            VStack(alignment: .leading, spacing: StitchSpacing.xs) {
                                Text("\(med.name) \(med.strength)")
                                    .font(Typography.titleMedium)
                                Text("\(med.dose) - \(med.frequency) for \(med.duration)")
                                    .font(Typography.bodyLarge)
                                if let instructions = med.instructions {
                                    Text(instructions)
                                        .font(Typography.bodyMedium)
                                        .foregroundStyle(Color.chettinadTextSecondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle("Prescription")
    }
}

struct InfoRow: View {
    let title: String
    let value: String
    var body: some View {
        HStack {
            Text(title).foregroundStyle(Color.chettinadTextSecondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
    }
}

struct PatientProfileView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var viewModel: PatientViewModel
    @State private var showingEdit = false
    @State private var activeSessions: [SessionInfo] = []
    
    var body: some View {
        NavigationView {
            List {
                if let bundle = viewModel.recordBundle {
                    Section(header: Text("Personal Info")) {
                        InfoRow(title: "Name", value: bundle.patient.name)
                        InfoRow(title: "MRN", value: bundle.patient.mrn)
                        InfoRow(title: "DOB", value: bundle.patient.dob)
                        InfoRow(title: "Gender", value: bundle.patient.gender)
                        if let email = bundle.patient.email, !email.isEmpty {
                            InfoRow(title: "Email", value: email)
                        }
                        InfoRow(title: "Phone", value: bundle.patient.phone)
                    }
                    
                    Section(header: Text("Address")) {
                        Text(bundle.patient.address ?? "")
                        Text("\(bundle.patient.city ?? ""), \(bundle.patient.state ?? "") \(bundle.patient.pin_code ?? "")")
                    }
                    
                    Section(header: Text("Emergency Contact")) {
                        InfoRow(title: "Phone", value: bundle.patient.emergency_contact ?? "")
                    }
                }
                
                if !activeSessions.isEmpty {
                    Section(header: Text("Active Sessions")) {
                        ForEach(activeSessions) { s in
                            VStack(alignment: .leading, spacing: StitchSpacing.xs) {
                                Text(s.current ? "This Device" : "Device").font(Typography.titleMedium)
                                Text(s.device_name ?? "Unknown Device").font(Typography.bodyLarge)
                                Text("Expires: \(String(s.expires_at.prefix(10)))").font(Typography.bodyMedium).foregroundStyle(Color.chettinadTextSecondary)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    Task { await revokeSession(s) }
                                } label: { Label("Revoke", systemImage: "trash") }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                
                Section {
                    Button(action: {
                        appState.logout()
                    }) {
                        Text("Sign Out")
                            .foregroundStyle(Color.chettinadError)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { showingEdit = true }
                }
            }
            .sheet(isPresented: $showingEdit) {
                EditProfileSheet().environmentObject(viewModel)
            }
        }
        .task { await fetchSessions() }
    }
    
    private func fetchSessions() async {
        do { activeSessions = try await APIClient().execute(endpoint: GetSessionsEndpoint()) } catch { print("Error: \(error)") }
    }
    private func revokeSession(_ session: SessionInfo) async {
        do {
            let _: [String: String]? = try? await APIClient().execute(endpoint: RevokeSessionEndpoint(sessionId: session.id))
            if session.current { appState.logout() } else { await fetchSessions() }
        } catch { print("Error: \(error)") }
    }
}

struct PatientAppointmentsView: View {
    @EnvironmentObject var viewModel: PatientViewModel
    @State private var showingBooking = false
    let onRecords: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.appointments.isEmpty {
                    VStack(spacing: StitchSpacing.lg) { Image(systemName: "calendar").font(.system(size: 48)).foregroundStyle(Color.chettinadTextSecondary); Text("No upcoming appointments").font(Typography.titleMedium); Text("Book an appointment with the\nObstetrics & Gynaecology care team.").font(Typography.bodyLarge).foregroundStyle(Color.chettinadTextSecondary).multilineTextAlignment(.center); Button("Request Appointment") { showingBooking = true }.buttonStyle(StitchPrimaryButtonStyle()) }.frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 40).listRowBackground(Color.clear)
                } else {
                    let upcoming = viewModel.appointments.filter { !["COMPLETED", "CANCELLED", "NO_SHOW"].contains($0.status) && (ISODate.parse($0.scheduled_at).map { date in date >= Date() } ?? false) }
                    let past = viewModel.appointments.filter { !upcoming.map(\.id).contains($0.id) }
                    if !upcoming.isEmpty {
                        Section("Upcoming") { 
                            ForEach(upcoming.sorted { $0.scheduled_at < $1.scheduled_at }) { apt in
                                appointmentRow(apt)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            Task { await viewModel.cancelAppointment(apt.id, version: apt.__v ?? 1) }
                                        } label: { Label("Cancel", systemImage: "xmark.circle") }
                                    }
                            }
                        }
                    }
                    if !past.isEmpty { Section("Past") { ForEach(past.sorted { $0.scheduled_at > $1.scheduled_at }) { appointmentRow($0) } } }
                }
            }
            .navigationTitle("Appointments")
            .toolbar { Button { showingBooking = true } label: { Label("Book", systemImage: "plus") } }
            .sheet(isPresented: $showingBooking) { AppointmentBookingSheet().environmentObject(viewModel) }
            .refreshable {
                await viewModel.fetchRecords()
            }
        }
    }

    private func appointmentRow(_ apt: Appointment) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(apt.doctor_name ?? "OG Doctor").font(Typography.titleMedium)
            Text("Obstetrics & Gynaecology · \(apt.reason ?? "Consultation")").font(Typography.bodyLarge).foregroundStyle(Color.chettinadTextSecondary)
            HStack { Text(formatDate(apt.scheduled_at)); Spacer(); StitchStatusChip(status: apt.status) }.font(Typography.bodyMedium)
            if !["COMPLETED", "CANCELLED", "NO_SHOW"].contains(apt.status) { Button("Add Records for this Appointment", action: onRecords).font(Typography.bodyMedium).buttonStyle(StitchSecondaryButtonStyle()) }
        }.padding(.vertical, 4)
    }
    
    private func formatDate(_ dateStr: String) -> String {
        ISODate.display(dateStr)
    }
    
    private func colorForStatus(_ status: String) -> Color {
        switch status {
        case "SCHEDULED": return .blue
        case "PENDING_CONFIRMATION": return .orange
        case "CONFIRMED": return .green
        case "CHECKED_IN": return .purple
        case "CANCELLED", "NO_SHOW": return .red
        case "COMPLETED": return .gray
        default: return .primary
        }
    }
}

private struct AppointmentBookingSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: PatientViewModel
    @State private var doctorId = ""
    @State private var date = Calendar.current.startOfDay(for: Date().addingTimeInterval(86400))
    @State private var selectedSlot = ""
    @State private var reason = ""
    @State private var saving = false

    var body: some View {
        NavigationView {
            Form {
                if let error = viewModel.errorMessage { Section { Text(error).foregroundColor(.chettinadError) } }
                Section("Department") { LabeledContent("Specialty", value: "Obstetrics & Gynaecology"); LabeledContent("Prefix", value: "OBST") }
                Section("Doctor and date") {
                    Picker("Doctor", selection: $doctorId) { Text("Select a doctor").tag(""); ForEach(viewModel.directory?.doctors ?? []) { Text($0.name).tag($0.id) } }
                    DatePicker("Date", selection: $date, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                }
                Section("Available times") {
                    if doctorId.isEmpty { Text("Choose an OG doctor to see real available slots.").foregroundStyle(Color.chettinadTextSecondary) }
                    else if viewModel.slots.isEmpty { Text("No available slots for this date.").foregroundStyle(Color.chettinadTextSecondary) }
                    else { Picker("Time", selection: $selectedSlot) { Text("Select a time").tag(""); ForEach(viewModel.slots) { Text(Self.time($0.scheduled_at) + " · " + $0.room).tag($0.scheduled_at) } } }
                }
                Section("Reason") { TextField("Reason for visit", text: $reason, axis: .vertical) }
                Section { Button(saving ? "Requesting…" : "Request Appointment") { saving = true; Task { if await viewModel.book(doctorId: doctorId, scheduledAt: selectedSlot, reason: reason) { dismiss() }; saving = false } }.disabled(doctorId.isEmpty || selectedSlot.isEmpty || reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || saving) }
            }
            .navigationTitle("Book appointment")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onAppear { if viewModel.recordBundle != nil { viewModel.errorMessage = nil } }
            .task(id: "\(doctorId)-\(date.timeIntervalSince1970)") { selectedSlot = ""; guard !doctorId.isEmpty else { return }; await viewModel.fetchSlots(doctorId: doctorId, date: date) }
        }
    }

    private static func time(_ value: String) -> String {
        ISODate.display(value, dateStyle: .none, timeStyle: .short)
    }
}
struct EditProfileSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var viewModel: PatientViewModel
    
    @State private var email = ""
    @State private var address = ""
    @State private var city = ""
    @State private var state = ""
    @State private var pinCode = ""
    @State private var emergencyContact = ""
    @State private var saving = false
    
    var body: some View {
        NavigationView {
            Form {
                if let error = viewModel.errorMessage { Section { Text(error).foregroundColor(.chettinadError) } }
                
                Section("Contact") {
                    TextField("Email", text: $email).keyboardType(.emailAddress).autocapitalization(.none)
                    TextField("Emergency Contact", text: $emergencyContact).keyboardType(.phonePad)
                }
                
                Section("Address") {
                    TextField("Address", text: $address)
                    TextField("City", text: $city)
                    TextField("State", text: $state)
                    TextField("PIN Code", text: $pinCode).keyboardType(.numberPad)
                }
            }
            .navigationTitle("Edit Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") {
                        saving = true
                        let version = viewModel.recordBundle?.patient.__v ?? 1
                        Task {
                            if await viewModel.updateProfile(email: email, address: address, city: city, state: state, pinCode: pinCode, emergencyContact: emergencyContact, version: version) {
                                dismiss()
                            }
                            saving = false
                        }
                    }.disabled(saving)
                }
            }
            .onAppear {
                if let p = viewModel.recordBundle?.patient {
                    email = p.email ?? ""
                    address = p.address ?? ""
                    city = p.city ?? ""
                    state = p.state ?? ""
                    pinCode = p.pin_code ?? ""
                    emergencyContact = p.emergency_contact ?? ""
                }
            }
        }
    }
}
import SwiftUI
import ChettinadCore

struct PatientQueueView: View {
    @State private var queueEntries: [QueueEntry] = []
    @State private var isLoading = false
    private let apiClient = APIClient()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                AppHeader(title: "Live Queue")
                
                ScrollView {
                    if isLoading && queueEntries.isEmpty {
                        ProgressView().padding()
                    } else if queueEntries.isEmpty {
                        StitchEmptyState(icon: "checkmark.circle.fill", title: "You're not currently in the queue.", message: "Check-in to your appointment at the hospital desk to track your wait time here.")
                            .padding(.top, 60)
                    } else {
                        VStack(spacing: StitchSpacing.lg) {
                            ForEach(queueEntries) { entry in
                                StitchCard {
                                    VStack(alignment: .leading, spacing: StitchSpacing.md) {
                                        HStack {
                                            Text("Token \(entry.token)")
                                                .font(Typography.titleLarge)
                                                .fontWeight(.bold)
                                                .foregroundColor(.chettinadPrimary)
                                            Spacer()
                                            StitchStatusChip(status: entry.status)
                                        }
                                        Text(entry.doctor_name)
                                            .font(Typography.titleMedium)
                                        
                                        Divider()
                                        
                                        HStack {
                                            VStack(alignment: .leading) {
                                                Text("Patients Ahead")
                                                    .font(Typography.bodyMedium)
                                                    .foregroundStyle(Color.chettinadTextSecondary)
                                                Text("\(entry.patients_ahead ?? 0)")
                                                    .font(Typography.titleMedium)
                                                    .fontWeight(.semibold)
                                            }
                                            Spacer()
                                            VStack(alignment: .trailing) {
                                                Text("Est. Wait Time")
                                                    .font(Typography.bodyMedium)
                                                    .foregroundStyle(Color.chettinadTextSecondary)
                                                Text("\(entry.estimated_wait ?? 0) mins")
                                                    .font(Typography.titleMedium)
                                                    .fontWeight(.semibold)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
                .refreshable {
                    await fetchQueue()
                }
            }
            .task {
                await fetchQueue()
            }
        }
    }
    
    @MainActor
    private func fetchQueue() async {
        isLoading = true
        do {
            queueEntries = try await apiClient.execute(endpoint: QueueEndpoint())
        } catch {
            print("Failed to fetch queue: \(error)")
        }
        isLoading = false
    }
}
