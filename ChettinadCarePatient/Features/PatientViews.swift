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
            AppHeader(title: "Chettinad Patient")
            
            ScrollView {
                if viewModel.isLoading {
                    ProgressView("Loading Dashboard...")
                        .padding()
                } else if let error = viewModel.errorMessage {
                    Text(error).foregroundColor(.chettinadError).padding()
                } else if let bundle = viewModel.recordBundle {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // Welcome Section
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Welcome back,")
                                .textStyle(Typography.titleMedium, color: .chettinadSecondary)
                            Text(bundle.patient.name)
                                .textStyle(Typography.headlineMedium, color: .chettinadPrimary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Next actions").textStyle(Typography.titleMedium, color: .chettinadPrimary)
                            if let appointment = viewModel.appointments.filter({ !["COMPLETED", "CANCELLED", "NO_SHOW"].contains($0.status) }).sorted(by: { $0.scheduled_at < $1.scheduled_at }).first {
                                Label("\(appointment.doctor_name ?? "OG Doctor") · \(String(appointment.scheduled_at.prefix(16)))", systemImage: "calendar")
                            } else { Label("Book your next OG appointment", systemImage: "calendar.badge.plus") }
                            if let task = viewModel.todayCareTasks.first(where: { $0.status == .DUE || $0.status == .UPCOMING }) { Label("\(task.title) · \(task.due_time)", systemImage: "checklist") }
                            else { Label("No Care Plan task is due now", systemImage: "checkmark.circle") }
                            Label("Upload a report or scan in Records", systemImage: "square.and.arrow.up")
                            Label("Review prescriptions and reminders", systemImage: "pills")
                            HStack { Button("Request Appointment", action: onAppointments).buttonStyle(.borderedProminent); Button("Upload Report", action: onRecords).buttonStyle(.bordered); Button("Add Record", action: onCarePlan).buttonStyle(.bordered) }
                            if let prescription = bundle.prescriptions.first { Text("Latest prescription · \(prescription.rx_content?.medications?.map(\.name).joined(separator: ", ") ?? "Available")").font(.caption).foregroundColor(.secondary) }
                            if let document = viewModel.documents.first { Text("Recent upload · \(document.title) · \(document.clinical_date)").font(.caption).foregroundColor(.secondary) }
                        }
                        .padding().frame(maxWidth: .infinity, alignment: .leading).background(Color.surfaceContainerLowest).cornerRadius(12).padding(.horizontal, 16)
                        
                        // Quick Stats
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            MetricsCard(title: "Encounters", value: "\(bundle.encounters.count)", iconName: "doc.text")
                            MetricsCard(title: "Notes", value: "\(bundle.notes.count)", iconName: "note.text")
                            MetricsCard(title: "Prescriptions", value: "\(bundle.prescriptions.count)", iconName: "pills.fill")
                            MetricsCard(title: "Lab Orders", value: "\(bundle.labs.count)", iconName: "testtube.2")
                        }
                        .padding(.horizontal, 16)
                        
                        // Active Encounters
                        let activeEncounters = bundle.encounters.filter { !$0.is_discharged }
                        if !activeEncounters.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Active Encounters")
                                    .textStyle(Typography.titleMedium, color: .chettinadPrimary)
                                    .padding(.horizontal, 16)
                                
                                ForEach(activeEncounters) { encounter in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(encounter.chief_complaint ?? "General Consultation")
                                                .textStyle(Typography.titleMedium, color: .chettinadTextPrimary)
                                            Text(encounter.phase)
                                                .textStyle(Typography.bodyMedium, color: .chettinadSecondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.chettinadSecondary)
                                    }
                                    .padding()
                                    .background(Color.surfaceContainerLowest)
                                    .cornerRadius(12)
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                        
                        // About Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("About Chettinad")
                                .textStyle(Typography.titleMedium, color: .chettinadPrimary)
                                .padding(.horizontal, 16)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Chettinad Hospital and Research Institute")
                                    .textStyle(Typography.titleSmall, color: .chettinadPrimary)
                                Text("Located at Kelambakkam, Tamil Nadu within the Chettinad Health City campus. 24/7 Trauma Care available.")
                                    .textStyle(Typography.bodyMedium, color: .chettinadTextSecondary)
                            }
                            .padding()
                            .background(Color.surfaceContainerLow)
                            .cornerRadius(12)
                            .padding(.horizontal, 16)
                        }
                        .padding(.bottom, 24)
                    }
                } else {
                    Text("No records found.")
                        .textStyle(Typography.bodyLarge, color: .chettinadSecondary)
                        .padding()
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
    
    var body: some View {
        VStack(spacing: 0) {
            AppHeader(title: "Medical Records")
            
            ScrollView {
                if viewModel.isLoading {
                    ProgressView()
                        .padding()
                } else if let bundle = viewModel.recordBundle {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // Header
                        VStack(alignment: .leading, spacing: 4) {
                            Text(bundle.patient.name)
                                .textStyle(Typography.titleLarge, color: .chettinadPrimary)
                            Text("MRN: \(bundle.patient.mrn) • \(bundle.patient.gender)")
                                .textStyle(Typography.bodyMedium, color: .chettinadSecondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.surfaceContainerLowest)
                        .padding(.top, 16)
                        
                        // Sections
                        VStack(alignment: .leading, spacing: 24) {
                            SectionView(title: "My documents") {
                                Button { importingDocument = true } label: { Label("Upload PDF or image", systemImage: "square.and.arrow.up") }.buttonStyle(.borderedProminent)
                                if viewModel.documents.isEmpty {
                                    Text("Your uploaded reports, scans and PDFs will appear here.").font(.subheadline).foregroundColor(.secondary)
                                } else {
                                    ForEach(viewModel.documents) { document in
                                        RecordCard {
                                            VStack(alignment: .leading, spacing: 10) {
                                                Button { Task { previewURL = try? await viewModel.apiClient.downloadPatientDocument(document) } } label: {
                                                    HStack { Image(systemName: document.mime_type == "application/pdf" ? "doc.richtext" : "photo"); VStack(alignment: .leading) { Text(document.title).font(.headline); Text("\(document.document_type.replacingOccurrences(of: "_", with: " ").capitalized) · \(document.clinical_date) · Patient uploaded").font(.caption).foregroundColor(.secondary) }; Spacer(); Image(systemName: "eye") }
                                                }.buttonStyle(.plain)
                                                Menu {
                                                    if document.appointment_id != nil { Button("Remove appointment attachment", role: .destructive) { Task { _ = await viewModel.linkDocument(document, to: nil) } } }
                                                    ForEach(viewModel.appointments) { appointment in
                                                        Button("\(String(appointment.scheduled_at.prefix(10))) · \(appointment.doctor_name ?? "OBST Doctor")") { Task { _ = await viewModel.linkDocument(document, to: appointment.id) } }
                                                    }
                                                } label: {
                                                    Label(document.appointment_id == nil ? "Attach to appointment" : "Change appointment attachment", systemImage: "paperclip")
                                                        .font(.caption)
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
                                            RecordCard {
                                                VStack(alignment: .leading, spacing: 4) {
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
                                            RecordCard {
                                                VStack(alignment: .leading, spacing: 4) {
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
                                        RecordCard {
                                            VStack(alignment: .leading, spacing: 8) {
                                                HStack {
                                                    Text(lab.name ?? lab.code ?? "Lab Test")
                                                        .textStyle(Typography.titleMedium, color: .chettinadTextPrimary)
                                                    Spacer()
                                                    Text(lab.status)
                                                        .textStyle(Typography.labelSmall, color: .chettinadSecondary)
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .background(Color.surfaceContainerHigh)
                                                        .cornerRadius(8)
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
                                        RecordCard {
                                            VStack(alignment: .leading, spacing: 8) {
                                                Text("Triage by \(tr.nurse_id ?? "Nurse")")
                                                    .textStyle(Typography.titleMedium, color: .chettinadTextPrimary)
                                                
                                                if let d = tr.data {
                                                    HStack(spacing: 16) {
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
                        .padding(.horizontal, 16)
                        .padding(.bottom, 24)
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
        }
        .navigationBarHidden(true)
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
            Section("File") { Text(fileURL.lastPathComponent); TextField("Title", text: $title); Picker("Document type", selection: $type) { ForEach(["LAB_REPORT", "SCAN", "PRESCRIPTION", "DISCHARGE_SUMMARY", "REFERRAL", "OTHER_MEDICAL_RECORD"], id: \.self) { Text($0.replacingOccurrences(of: "_", with: " ").capitalized) } }; DatePicker("Report date", selection: $clinicalDate, in: ...Date(), displayedComponents: .date) }
            Section("Visit association") { Picker("Appointment", selection: $appointmentId) { Text("No appointment").tag(""); ForEach(viewModel.appointments) { Text("\(String($0.scheduled_at.prefix(10))) · \($0.doctor_name ?? "OG Doctor")").tag($0.id) } }; TextField("Optional patient note", text: $note, axis: .vertical) }
        }.navigationTitle("Upload document").toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }; ToolbarItem(placement: .confirmationAction) { Button(saving ? "Uploading…" : "Upload") { saving = true; let formatter = DateFormatter(); formatter.dateFormat = "yyyy-MM-dd"; Task { if await viewModel.uploadDocument(fileURL: fileURL, title: title, documentType: type, clinicalDate: formatter.string(from: clinicalDate), appointmentId: appointmentId.isEmpty ? nil : appointmentId, note: note.isEmpty ? nil : note) { dismiss() }; saving = false } }.disabled(saving || title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) } } }
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
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .textStyle(Typography.titleMedium, color: .chettinadPrimary)
            content
        }
    }
}

struct RecordCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Color.surfaceContainerLowest)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
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
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(med.name) \(med.strength)")
                                    .font(.headline)
                                Text("\(med.dose) - \(med.frequency) for \(med.duration)")
                                    .font(.subheadline)
                                if let instructions = med.instructions {
                                    Text(instructions)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
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
            Text(title).foregroundColor(.secondary)
            Spacer()
            Text(value).multilineTextAlignment(.trailing)
        }
    }
}

struct PatientProfileView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var viewModel: PatientViewModel
    
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
                
                Section {
                    Button(action: {
                        appState.logout()
                    }) {
                        Text("Sign Out")
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("Profile")
        }
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
                    VStack(spacing: 16) { Image(systemName: "calendar").font(.system(size: 48)).foregroundColor(.secondary); Text("No upcoming appointments").font(.headline); Text("Book an appointment with the\nObstetrics & Gynaecology care team.").font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center); Button("Request Appointment") { showingBooking = true }.buttonStyle(.borderedProminent) }.frame(maxWidth: .infinity, alignment: .center).padding(.vertical, 40).listRowBackground(Color.clear)
                } else {
                    let upcoming = viewModel.appointments.filter { !["COMPLETED", "CANCELLED", "NO_SHOW"].contains($0.status) && $0.scheduled_at >= ISO8601DateFormatter().string(from: Date()) }
                    let past = viewModel.appointments.filter { !upcoming.map(\.id).contains($0.id) }
                    if !upcoming.isEmpty {
                        Section("Upcoming") { ForEach(upcoming.sorted { $0.scheduled_at < $1.scheduled_at }) { appointmentRow($0) } }
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
            Text(apt.doctor_name ?? "OG Doctor").font(.headline)
            Text("Obstetrics & Gynaecology · \(apt.reason ?? "Consultation")").font(.subheadline).foregroundColor(.secondary)
            HStack { Text(formatDate(apt.scheduled_at)); Spacer(); Text(apt.status == "PENDING_CONFIRMATION" ? "Awaiting confirmation" : apt.status.replacingOccurrences(of: "_", with: " ")).foregroundColor(colorForStatus(apt.status)) }.font(.caption)
            if !["COMPLETED", "CANCELLED", "NO_SHOW"].contains(apt.status) { Button("Add Records for this Appointment", action: onRecords).font(.caption).buttonStyle(.bordered) }
        }.padding(.vertical, 4)
    }
    
    private func formatDate(_ dateStr: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateStr) {
            let displayFormatter = DateFormatter()
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return String(dateStr.prefix(10))
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
                Section("Department") { LabeledContent("Specialty", value: "Obstetrics & Gynaecology"); LabeledContent("Prefix", value: "OBST") }
                Section("Doctor and date") {
                    Picker("Doctor", selection: $doctorId) { Text("Select a doctor").tag(""); ForEach(viewModel.directory?.doctors ?? []) { Text($0.name).tag($0.id) } }
                    DatePicker("Date", selection: $date, in: Calendar.current.startOfDay(for: Date())..., displayedComponents: .date)
                }
                Section("Available times") {
                    if doctorId.isEmpty { Text("Choose an OG doctor to see real available slots.").foregroundColor(.secondary) }
                    else if viewModel.slots.isEmpty { Text("No available slots for this date.").foregroundColor(.secondary) }
                    else { Picker("Time", selection: $selectedSlot) { Text("Select a time").tag(""); ForEach(viewModel.slots) { Text(Self.time($0.scheduled_at) + " · " + $0.room).tag($0.scheduled_at) } } }
                }
                Section("Reason") { TextField("Reason for visit", text: $reason, axis: .vertical) }
                Section { Button(saving ? "Requesting…" : "Request Appointment") { saving = true; Task { if await viewModel.book(doctorId: doctorId, scheduledAt: selectedSlot, reason: reason) { dismiss() }; saving = false } }.disabled(doctorId.isEmpty || selectedSlot.isEmpty || reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || saving) }
            }
            .navigationTitle("Book appointment")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .task(id: "\(doctorId)-\(date.timeIntervalSince1970)") { selectedSlot = ""; guard !doctorId.isEmpty else { return }; await viewModel.fetchSlots(doctorId: doctorId, date: date) }
        }
    }

    private static func time(_ value: String) -> String {
        let input = ISO8601DateFormatter(); guard let date = input.date(from: value) else { return value }
        let output = DateFormatter(); output.timeStyle = .short; return output.string(from: date)
    }
}
