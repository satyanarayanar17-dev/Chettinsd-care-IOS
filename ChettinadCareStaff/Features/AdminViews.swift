import SwiftUI
import ChettinadCore

struct AdminDashboardView: View {
    @StateObject private var viewModel = AdminDashboardViewModel()
    @State private var showBooking = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                AppHeader(title: "Admin Dashboard")
                
                List {
                    if let error = viewModel.errorMessage {
                        Text(error).foregroundColor(.red)
                    }
                    
                    if viewModel.isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else if viewModel.appointments.isEmpty {
                        Text("No appointments for today.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.appointments.sorted(by: { $0.scheduled_at < $1.scheduled_at })) { apt in
                            AppointmentAdminCard(appointment: apt, onCheckIn: {
                                Task { await viewModel.checkIn(appointmentId: apt.id) }
                            })
                        }
                    }
                }
                .refreshable {
                    await viewModel.fetchAppointments()
                }
            }
            .navigationBarHidden(true)
            .task {
                await viewModel.fetchAppointments()
            }
            .overlay(alignment: .bottomTrailing) {
                Button(action: { showBooking = true }) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .padding()
            }
            .sheet(isPresented: $showBooking, onDismiss: {
                Task { await viewModel.fetchAppointments() }
            }) {
                BookAppointmentView()
            }
        }
    }
}

struct AppointmentAdminCard: View {
    let appointment: Appointment
    let onCheckIn: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Patient: \(appointment.patient_id.prefix(8))")
                    .font(.headline)
                Spacer()
                Text(appointment.status)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(colorForStatus(appointment.status))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(colorForStatus(appointment.status).opacity(0.1))
                    .cornerRadius(8)
            }
            
            Text("Doctor: \(appointment.doctor_id)")
                .font(.subheadline)
            
            Text(formatDate(appointment.scheduled_at))
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let reason = appointment.reason {
                Text("Reason: \(reason)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if appointment.status == "CONFIRMED" {
                Button(action: onCheckIn) {
                    Text("Check In")
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func formatDate(_ dateStr: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateStr) {
            let displayFormatter = DateFormatter()
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return String(dateStr.prefix(16))
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

struct BookAppointmentView: View {
    @StateObject private var viewModel = BookAppointmentViewModel()
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error).foregroundColor(.red)
                    }
                }
                
                Section(header: Text("Patient Search")) {
                    HStack {
                        TextField("Name, Phone, or MRN", text: $viewModel.searchQuery)
                        Button("Search") {
                            Task { await viewModel.searchPatients() }
                        }
                    }
                    if viewModel.isSearching {
                        ProgressView()
                    }
                    
                    if !viewModel.searchResults.isEmpty {
                        Picker("Select Patient", selection: $viewModel.selectedPatientId) {
                            Text("None").tag(String?.none)
                            ForEach(viewModel.searchResults) { p in
                                Text("\(p.name) (\(p.phone))").tag(String?.some(p.id))
                            }
                        }
                    }
                }
                
                Section(header: Text("Doctor & Schedule")) {
                    Picker("Select Doctor", selection: $viewModel.selectedDoctorId) {
                        Text("None").tag(String?.none)
                        ForEach(viewModel.doctors) { d in
                            Text("\(d.name) - \(d.department)").tag(String?.some(d.id))
                        }
                    }
                    .onChange(of: viewModel.selectedDoctorId) { _ in
                        Task { await viewModel.fetchSlots() }
                    }
                    
                    DatePicker("Date", selection: $viewModel.selectedDate, displayedComponents: .date)
                        .onChange(of: viewModel.selectedDate) { _ in
                            Task { await viewModel.fetchSlots() }
                        }
                    
                    if !viewModel.availableSlots.isEmpty {
                        Picker("Time Slot", selection: $viewModel.selectedSlot) {
                            Text("None").tag(String?.none)
                            ForEach(viewModel.availableSlots, id: \.scheduled_at) { slot in
                                Text(formatTime(slot.scheduled_at)).tag(String?.some(slot.scheduled_at))
                            }
                        }
                    } else if viewModel.selectedDoctorId != nil {
                        Text("No slots available").foregroundColor(.secondary)
                    }
                }
                
                Section(header: Text("Details")) {
                    TextField("Reason for visit", text: $viewModel.reason)
                }
            }
            .navigationTitle("Book Appointment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Book") {
                        Task {
                            if await viewModel.bookAppointment() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.selectedPatientId == nil || viewModel.selectedDoctorId == nil || viewModel.selectedSlot == nil || viewModel.isSubmitting)
                }
            }
            .task {
                await viewModel.fetchDoctors()
            }
        }
    }
    
    private func formatTime(_ dateStr: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateStr) {
            let displayFormatter = DateFormatter()
            displayFormatter.timeStyle = .short
            return displayFormatter.string(from: date)
        }
        return String(dateStr.suffix(13).prefix(5))
    }
}

struct AdminTabView: View {
    var body: some View {
        TabView {
            AdminMetricsView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar")
                }
            
            AdminDashboardView()
                .tabItem {
                    Label("Appointments", systemImage: "calendar")
                }
            
            StaffManagementView()
                .tabItem {
                    Label("Staff", systemImage: "person.3")
                }
        }
    }
}

struct StaffManagementView: View {
    @StateObject private var viewModel = StaffManagementViewModel()
    @State private var showCreate = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                AppHeader(title: "Staff Management")
                
                List {
                    if let error = viewModel.errorMessage {
                        Text(error).foregroundColor(.red)
                    }
                    
                    if viewModel.isLoading {
                        ProgressView().frame(maxWidth: .infinity)
                    } else if viewModel.staffMembers.isEmpty {
                        Text("No staff found.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.staffMembers) { staff in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(staff.name)
                                        .font(.headline)
                                    Text("\(staff.role)\(staff.department != nil ? " • \(staff.department!)" : "")")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button(action: {
                                    Task { await viewModel.toggleStaff(staffId: staff.id, active: staff.is_active == 1 ? false : true) }
                                }) {
                                    if staff.is_active == 1 {
                                        Text("Active")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.green)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.green.opacity(0.1))
                                            .cornerRadius(8)
                                    } else {
                                        Text("Inactive")
                                            .font(.caption)
                                            .fontWeight(.bold)
                                            .foregroundColor(.gray)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.gray.opacity(0.1))
                                            .cornerRadius(8)
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .refreshable {
                    await viewModel.fetchStaff()
                }
            }
            .navigationBarHidden(true)
            .task {
                await viewModel.fetchStaff()
            }
            .overlay(alignment: .bottomTrailing) {
                Button(action: { showCreate = true }) {
                    Image(systemName: "plus")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .clipShape(Circle())
                        .shadow(radius: 4)
                }
                .padding()
            }
            .sheet(isPresented: $showCreate) {
                CreateStaffView(viewModel: viewModel)
            }
        }
    }
}

struct AdminMetricsView: View {
    @StateObject private var viewModel = AdminMetricsViewModel()
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                AppHeader(title: "Dashboard")
                if let error = viewModel.errorMessage {
                    Text(error).foregroundColor(.red).padding()
                }
                if let metrics = viewModel.metrics {
                    List {
                        Section(header: Text("Today's Overview")) {
                            HStack { Text("Total Appointments"); Spacer(); Text("\(metrics.appointments)").bold() }
                            HStack { Text("Checked In"); Spacer(); Text("\(metrics.checked_in)").bold() }
                            HStack { Text("Waiting"); Spacer(); Text("\(metrics.waiting)").bold() }
                            HStack { Text("In Triage/Consult"); Spacer(); Text("\(metrics.triage + metrics.consultation)").bold() }
                            HStack { Text("Completed"); Spacer(); Text("\(metrics.completed)").bold() }
                        }
                        Section(header: Text("Doctor Metrics")) {
                            ForEach(metrics.doctors) { d in
                                VStack(alignment: .leading) {
                                    Text(d.name).font(.headline)
                                    HStack {
                                        Text("Appts: \(d.appointments)")
                                        Spacer()
                                        Text("Wait: \(d.waiting)")
                                        Spacer()
                                        Text("Done: \(d.completed)")
                                    }.font(.subheadline).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    .refreshable { await viewModel.fetchMetrics() }
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationBarHidden(true)
            .task { await viewModel.fetchMetrics() }
        }
    }
}

struct CreateStaffView: View {
    @ObservedObject var viewModel: StaffManagementViewModel
    @Environment(\.dismiss) var dismiss
    
    @State private var id = ""
    @State private var name = ""
    @State private var role = "DOCTOR"
    @State private var department = ""
    @State private var password = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Staff Details")) {
                    TextField("Username (ID)", text: $id)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Full Name", text: $name)
                    Picker("Role", selection: $role) {
                        Text("Doctor").tag("DOCTOR")
                        Text("Nurse").tag("NURSE")
                        Text("Admin").tag("ADMIN")
                    }
                    Picker("Department", selection: $department) {
                        Text("None").tag("")
                        ForEach(viewModel.departments) { d in
                            Text(d.name).tag(d.name)
                        }
                    }
                    SecureField("Initial Password", text: $password)
                }
            }
            .navigationTitle("Add Staff")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        Task {
                            if await viewModel.createStaff(id: id, name: name, role: role, department: department, password: password) {
                                dismiss()
                            }
                        }
                    }
                    .disabled(id.isEmpty || name.isEmpty || password.isEmpty)
                }
            }
        }
    }
}
