struct DoctorScheduleView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = DoctorScheduleViewModel()
    @State private var showingAddLeave = false
    @State private var leaveDate = Date()
    @State private var leaveReason = ""
    
    let weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                AppHeader(title: "My Availability")
                
                if viewModel.isLoading {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        if let error = viewModel.errorMessage {
                            Text(error).foregroundColor(.red)
                        }
                        
                        if let directory = viewModel.directory {
                            let doctors = directory.doctors.filter { appState.role == "ADMIN" || $0.id == appState.session?.id }
                            
                            Section("Weekly Schedules") {
                                if doctors.isEmpty || !doctors.contains(where: { !$0.schedules.isEmpty }) {
                                    Text("No schedules found.").foregroundColor(.secondary)
                                } else {
                                    ForEach(doctors) { doctor in
                                        ForEach(doctor.schedules) { s in
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("\(doctor.name)")
                                                    .font(.headline)
                                                HStack {
                                                    Text(weekdays[s.weekday])
                                                        .fontWeight(.semibold)
                                                    Spacer()
                                                    Text("\(s.start_time) - \(s.end_time)")
                                                }
                                                HStack {
                                                    Text("Room: \(s.room)")
                                                    Spacer()
                                                    Text("\(s.slot_minutes) mins/slot")
                                                }
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            }
                                            .padding(.vertical, 4)
                                        }
                                    }
                                }
                            }
                        }
                        
                        Section(header: HStack {
                            Text("Unavailability / Leaves")
                            Spacer()
                            Button(action: { showingAddLeave = true }) {
                                Image(systemName: "plus")
                            }
                        }) {
                            if viewModel.unavailability.isEmpty {
                                Text("No upcoming leaves.").foregroundColor(.secondary)
                            } else {
                                ForEach(viewModel.unavailability) { leave in
                                    let docName = viewModel.directory?.doctors.first(where: { $0.id == leave.doctor_id })?.name ?? leave.doctor_id
                                    HStack {
                                        VStack(alignment: .leading) {
                                            Text(docName).font(.headline)
                                            Text(leave.date).font(.subheadline)
                                            Text(leave.reason).font(.caption).foregroundColor(.secondary)
                                        }
                                        Spacer()
                                        Button(action: {
                                            Task { await viewModel.deleteLeave(id: leave.id) }
                                        }) {
                                            Text("Restore")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .refreshable {
                        await viewModel.fetchData()
                    }
                }
            }
            .sheet(isPresented: $showingAddLeave) {
                NavigationView {
                    Form {
                        DatePicker("Leave Date", selection: $leaveDate, displayedComponents: .date)
                        TextField("Reason", text: $leaveReason)
                    }
                    .navigationTitle("Add Leave")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { showingAddLeave = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                Task {
                                    let formatter = DateFormatter()
                                    formatter.dateFormat = "yyyy-MM-dd"
                                    let dateStr = formatter.string(from: leaveDate)
                                    let docId = appState.session?.id ?? ""
                                    if await viewModel.addLeave(doctorId: docId, date: dateStr, reason: leaveReason) {
                                        showingAddLeave = false
                                        leaveReason = ""
                                    }
                                }
                            }
                            .disabled(leaveReason.isEmpty)
                        }
                    }
                }
            }
            .task {
                await viewModel.fetchData()
            }
        }
    }
}
