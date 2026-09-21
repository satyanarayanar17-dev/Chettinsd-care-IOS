import SwiftUI
import ChettinadCore

struct PatientDashboardView: View {
    @EnvironmentObject var viewModel: PatientViewModel
    
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
        }
        .navigationBarHidden(true)
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
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.appointments.isEmpty {
                    Text("No appointments found.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(viewModel.appointments.sorted(by: { $0.scheduled_at > $1.scheduled_at })) { apt in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(apt.reason ?? "Consultation")
                                .font(.headline)
                            HStack {
                                Text(formatDate(apt.scheduled_at))
                                Spacer()
                                Text(apt.status)
                                    .fontWeight(.medium)
                                    .foregroundColor(colorForStatus(apt.status))
                            }
                            .font(.subheadline)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Appointments")
            .refreshable {
                await viewModel.fetchRecords()
            }
        }
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
        case "CONFIRMED": return .green
        case "CHECKED_IN": return .purple
        case "CANCELLED", "NO_SHOW": return .red
        case "COMPLETED": return .gray
        default: return .primary
        }
    }
}
