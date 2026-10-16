import SwiftUI
import ChettinadCore

enum StaffDestination: String, CaseIterable, Identifiable {
    case overview, queue, appointments, labs, staff, availability, profile
    var id: Self { self }
    var title: String {
        switch self {
        case .overview: return "Overview"
        case .queue: return "Queue"
        case .appointments: return "Appointments"
        case .labs: return "Laboratory"
        case .staff: return "Staff"
        case .availability: return "Availability"
        case .profile: return "Profile"
        }
    }
    var symbol: String {
        switch self {
        case .overview: return "chart.bar"
        case .queue: return "person.3.sequence"
        case .appointments: return "calendar"
        case .labs: return "testtube.2"
        case .staff: return "person.3"
        case .availability: return "clock"
        case .profile: return "person.crop.circle"
        }
    }
    static func destinations(for role: String) -> [Self] {
        switch role {
        case "ADMIN": return [.overview, .appointments, .staff, .availability, .profile]
        case "DOCTOR": return [.queue, .appointments, .labs, .availability, .profile]
        case "NURSE": return [.queue, .appointments, .labs, .profile]
        default: return []
        }
    }
}

struct StaffPermissions {
    static func canConfirm(role: String) -> Bool { ["ADMIN", "DOCTOR"].contains(role) }
    static func canCheckIn(role: String) -> Bool { ["ADMIN", "DOCTOR"].contains(role) }
    static func canBook(role: String) -> Bool { ["ADMIN", "DOCTOR"].contains(role) }
}

struct SideTabsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selected: StaffDestination?
    private var destinations: [StaffDestination] { StaffDestination.destinations(for: appState.role) }

    var body: some View {
        Group {
            if sizeClass == .compact {
                TabView(selection: $selected) {
                    ForEach(destinations) { destination in
                        content(for: destination)
                            .tabItem { Label(LocalizedStringKey(destination.title), systemImage: destination.symbol) }
                            .tag(Optional(destination))
                    }
                }
            } else {
                NavigationSplitView {
                    List(destinations, selection: $selected) { destination in
                        NavigationLink(value: destination) {
                            Label(LocalizedStringKey(destination.title), systemImage: destination.symbol)
                        }
                    }
                    .navigationTitle("Chettinad Care")
                } detail: {
                    if let selected, destinations.contains(selected) { content(for: selected) }
                    else { StitchEmptyState(icon: "stethoscope", title: "Choose a workspace", message: "Select a section to continue.") }
                }
            }
        }
        .task(id: appState.role) { selected = destinations.first }
    }

    @ViewBuilder private func content(for destination: StaffDestination) -> some View {
        switch destination {
        case .overview: AdminMetricsView()
        case .queue:
            if appState.role == "DOCTOR" { DoctorQueueView() }
            else if appState.role == "NURSE" { NurseTriageView() }
        case .appointments: AdminDashboardView()
        case .labs: LabWorkbenchView()
        case .staff: StaffManagementView()
        case .availability: DoctorAvailabilityView()
        case .profile: StaffProfileView()
        }
    }
}

struct StaffProfileView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @State private var profile: UserSession?
    @State private var sessions: [SessionInfo] = []
    @State private var errorMessage: String?
    @State private var isLoading = false
    @State private var pendingRevoke: SessionInfo?
    @State private var isRevoking = false
    private let apiClient = APIClient()

    var body: some View {
        NavigationStack {
            List {
                if let errorMessage {
                    StitchErrorState(message: errorMessage) { Task { await load() } }
                }
                if isLoading && profile == nil { ProgressView("Loading your profile…") }
                if let profile {
                    Section { InterfaceLanguagePicker() }
                    Section("Staff details") {
                        LabeledContent("Name", value: profile.name)
                        LabeledContent("Role", value: profile.role.capitalized)
                        LabeledContent("Department", value: profile.department ?? "Unassigned")
                    }
                }
                Section("Active sessions") {
                    ForEach(sessions) { session in
                        VStack(alignment: .leading, spacing: StitchSpacing.sm) {
                            Text(session.device_name ?? "Device").font(Typography.titleSmall)
                            Text(session.current ? "This device" : "Expires \(ISODate.display(session.expires_at))")
                                .font(Typography.bodySmall).foregroundStyle(Color.chettinadTextSecondary)
                            if !session.current {
                                Button("Sign out this device", role: .destructive) { pendingRevoke = session }
                                    .disabled(isRevoking)
                            }
                        }
                    }
                    if sessions.isEmpty && !isLoading && errorMessage == nil {
                        Text("No active sessions to display.").foregroundStyle(.secondary)
                    }
                }
                Section { Button("Sign Out", role: .destructive) { appState.logout() } }
            }
            .navigationTitle("Profile & sessions")
            .task(id: scenePhase) { if scenePhase == .active { await load() } }
            .refreshable { await load() }
            .confirmationDialog("Sign out this device?", isPresented: Binding(get: { pendingRevoke != nil }, set: { if !$0 { pendingRevoke = nil } }), presenting: pendingRevoke) { session in
                Button("Sign out device", role: .destructive) { Task { await revoke(session) } }
                Button("Cancel", role: .cancel) { }
            }
        }
    }

    @MainActor private func load() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            async let profileRequest: UserSession = apiClient.execute(endpoint: OPDSessionEndpoint())
            async let sessionsRequest: [SessionInfo] = apiClient.execute(endpoint: GetSessionsEndpoint())
            let loaded = try await (profileRequest, sessionsRequest)
            guard !Task.isCancelled else { return }
            profile = loaded.0
            sessions = loaded.1
        } catch { if !Task.isCancelled { errorMessage = "We couldn't load your profile and sessions. Please retry." } }
    }

    @MainActor private func revoke(_ session: SessionInfo) async {
        isRevoking = true
        defer { isRevoking = false }
        do {
            let _: EmptyResponse = try await apiClient.execute(endpoint: RevokeSessionEndpoint(sessionId: session.id))
            await load()
        } catch { errorMessage = "We couldn't sign out that device. Please retry." }
    }
}

struct DoctorAvailabilityView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = DoctorScheduleViewModel()
    @State private var userId: String?
    @State private var showingLeave = false
    private var doctors: [OPDDoctor] {
        viewModel.directory?.doctors.filter { appState.role == "ADMIN" || $0.id == userId } ?? []
    }

    var body: some View {
        NavigationStack {
            List {
                if let error = viewModel.errorMessage {
                    StitchErrorState(message: error) { Task { await viewModel.fetchData() } }
                }
                if viewModel.isLoading && viewModel.directory == nil { ProgressView("Loading availability…") }
                Section("Weekly schedules") {
                    ForEach(doctors) { doctor in
                        ForEach(doctor.schedules) { schedule in
                            VStack(alignment: .leading, spacing: StitchSpacing.xs) {
                                Text(doctor.name).font(Typography.titleSmall)
                                Text("\(weekday(schedule.weekday)) · \(schedule.start_time)–\(schedule.end_time)")
                                Text("Room \(schedule.room) · \(schedule.slot_minutes) minute slots")
                                    .font(Typography.bodySmall).foregroundStyle(.secondary)
                            }
                        }
                    }
                    if !viewModel.isLoading && doctors.allSatisfy({ $0.schedules.isEmpty }) && viewModel.errorMessage == nil {
                        Text("No weekly schedules are available.").foregroundStyle(.secondary)
                    }
                }
                Section("Upcoming unavailability") {
                    ForEach(viewModel.unavailability) { leave in
                        VStack(alignment: .leading, spacing: StitchSpacing.sm) {
                            Text(doctors.first(where: { $0.id == leave.doctor_id })?.name ?? "Doctor").font(Typography.titleSmall)
                            Text("\(leave.date) · \(leave.reason)")
                            Button("Restore availability") { Task { await viewModel.deleteLeave(id: leave.id) } }
                        }
                    }
                    if viewModel.unavailability.isEmpty && !viewModel.isLoading && viewModel.errorMessage == nil {
                        Text("No upcoming leave.").foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Availability")
            .toolbar { Button { showingLeave = true } label: { Label("Add leave", systemImage: "plus") }.disabled(doctors.isEmpty) }
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                userId = await SessionManager.shared.getSession()?.userId
                await viewModel.fetchData()
            }
            .refreshable { await viewModel.fetchData() }
            .sheet(isPresented: $showingLeave) { StaffLeaveSheet(viewModel: viewModel, doctors: doctors) }
        }
    }
    private func weekday(_ index: Int) -> String {
        let names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return names.indices.contains(index) ? names[index] : "Day unavailable"
    }
}

private struct StaffLeaveSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: DoctorScheduleViewModel
    let doctors: [OPDDoctor]
    @State private var doctorId = ""
    @State private var date = Date()
    @State private var reason = ""
    @State private var saving = false

    var body: some View {
        NavigationStack {
            Form {
                if let error = viewModel.errorMessage { StitchErrorState(message: error) }
                Picker("Doctor", selection: $doctorId) { ForEach(doctors) { Text($0.name).tag($0.id) } }
                DatePicker("Leave date", selection: $date, in: Date()..., displayedComponents: .date)
                TextField("Reason", text: $reason)
                Text("Patients will not be offered appointment slots on this date. Existing confirmed bookings must be rescheduled first.")
                    .font(Typography.bodySmall).foregroundStyle(.secondary)
            }
            .navigationTitle("Add unavailability")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(saving) }
                ToolbarItem(placement: .confirmationAction) {
                    Button(saving ? "Saving…" : "Save") {
                        saving = true
                        Task {
                            let formatter = DateFormatter()
                            formatter.calendar = Calendar(identifier: .gregorian)
                            formatter.locale = Locale(identifier: "en_US_POSIX")
                            formatter.timeZone = TimeZone(identifier: "Asia/Kolkata")
                            formatter.dateFormat = "yyyy-MM-dd"
                            if await viewModel.addLeave(doctorId: doctorId, date: formatter.string(from: date), reason: reason.trimmingCharacters(in: .whitespacesAndNewlines)) { dismiss() }
                            saving = false
                        }
                    }.disabled(saving || doctorId.isEmpty || reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .task { doctorId = doctors.first?.id ?? ""; viewModel.errorMessage = nil }
            .interactiveDismissDisabled(saving)
        }
    }
}
