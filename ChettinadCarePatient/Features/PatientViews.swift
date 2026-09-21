import SwiftUI
import ChettinadCore

struct PatientDashboardView: View {
    @EnvironmentObject var viewModel: PatientViewModel
    
    var body: some View {
        NavigationView {
            ScrollView {
                if viewModel.isLoading {
                    ProgressView("Loading Dashboard...")
                        .padding()
                } else if let error = viewModel.errorMessage {
                    Text(error).foregroundColor(.red).padding()
                } else if let bundle = viewModel.recordBundle {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // Welcome Card
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Welcome,")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text(bundle.patient.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            Spacer()
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .frame(width: 50, height: 50)
                                .foregroundColor(.blue)
                        }
                        .padding()
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(12)
                        
                        // Encounters Summary
                        let activeEncounters = bundle.encounters.filter { !$0.is_discharged }
                        if !activeEncounters.isEmpty {
                            VStack(alignment: .leading) {
                                Text("Active Encounters")
                                    .font(.headline)
                                ForEach(activeEncounters) { encounter in
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(encounter.chief_complaint ?? "General Consultation")
                                                .font(.subheadline)
                                                .fontWeight(.medium)
                                            Text(encounter.phase)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.secondary)
                                    }
                                    .padding()
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        
                        // Quick Stats
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            StatCard(title: "Encounters", count: bundle.encounters.count, icon: "doc.text")
                            StatCard(title: "Notes", count: bundle.notes.count, icon: "note.text")
                            StatCard(title: "Prescriptions", count: bundle.prescriptions.count, icon: "pills.fill")
                            StatCard(title: "Lab Orders", count: bundle.labs.count, icon: "testtube.2")
                        }
                    }
                    .padding()
                } else {
                    Text("No records found.")
                        .foregroundColor(.secondary)
                        .padding()
                }
            }
            .navigationTitle("Dashboard")
            .refreshable {
                await viewModel.fetchRecords()
            }
        }
    }
}

struct StatCard: View {
    let title: String
    let count: Int
    let icon: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(.blue)
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct PatientRecordsView: View {
    @EnvironmentObject var viewModel: PatientViewModel
    
    var body: some View {
        NavigationView {
            List {
                if viewModel.isLoading {
                    ProgressView()
                } else if let bundle = viewModel.recordBundle {
                    if !bundle.notes.isEmpty {
                        Section(header: Text("Clinical Notes")) {
                            ForEach(bundle.notes) { note in
                                NavigationLink(destination: NoteDetailView(note: note)) {
                                    VStack(alignment: .leading) {
                                        Text(note.author_name ?? "Doctor Note")
                                            .font(.headline)
                                        Text(note.created_at.prefix(10))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    
                    if !bundle.prescriptions.isEmpty {
                        Section(header: Text("Prescriptions")) {
                            ForEach(bundle.prescriptions) { rx in
                                NavigationLink(destination: PrescriptionDetailView(prescription: rx)) {
                                    VStack(alignment: .leading) {
                                        Text(rx.doctor_name ?? "Prescription")
                                            .font(.headline)
                                        Text(rx.created_at.prefix(10))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    
                    if !bundle.labs.isEmpty {
                        Section(header: Text("Lab Orders")) {
                            ForEach(bundle.labs) { lab in
                                VStack(alignment: .leading) {
                                    Text(lab.name ?? lab.code ?? "Lab Test")
                                        .font(.headline)
                                    HStack {
                                        Text("Status: \(lab.status)")
                                        Spacer()
                                        if let result = lab.result {
                                            Text(result)
                                                .fontWeight(.bold)
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    if !bundle.triage.isEmpty {
                        Section(header: Text("Triage History")) {
                            ForEach(bundle.triage) { tr in
                                VStack(alignment: .leading) {
                                    Text("Triage by \(tr.nurse_id ?? "Nurse")")
                                        .font(.subheadline)
                                    if let d = tr.data {
                                        HStack {
                                            if let t = d.temperature { Text("Temp: \(String(format: "%.1f", t))") }
                                            if let s = d.systolic, let dia = d.diastolic { Text("BP: \(s)/\(dia)") }
                                        }
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    
                }
            }
            .navigationTitle("Records")
            .refreshable {
                await viewModel.fetchRecords()
            }
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
