import SwiftUI
import ChettinadCore

struct PatientCarePlanView: View {
    @StateObject private var viewModel = CarePlanViewModel()
    @State private var showingMeasurementSheet = false
    @State private var selectedTask: CarePlanOccurrenceDTO?
    @State private var measurementValue: String = ""
    @State private var measurementNote: String = ""
    @State private var showingSelfRecord = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.tasks.isEmpty {
                    ProgressView("Loading Care Plan...")
                } else if let error = viewModel.errorMessage, viewModel.tasks.isEmpty {
                    errorStateView(error)
                } else if viewModel.tasks.isEmpty && !viewModel.isLoading {
                    emptyStateView
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            progressHeader

                            if let error = viewModel.errorMessage {
                                Text(error)
                                    .font(.footnote)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                            }

                            Button { showingSelfRecord = true } label: { Label("Add Record", systemImage: "plus.circle.fill").frame(maxWidth: .infinity).padding(12) }
                                .buttonStyle(.borderedProminent).padding(.horizontal)
                            
                            if let next = nextActionTask {
                                nextActionCard(task: next)
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Today's Checklist").font(.headline).padding(.horizontal)
                                ForEach(viewModel.tasks) { occurrence in
                                    taskRow(occurrence)
                                }
                            }

                            if !viewModel.timeline.isEmpty {
                                timelineSection
                            }
                            if !viewModel.selfRecords.isEmpty { selfRecordSection }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Care Plan")
            .task {
                await viewModel.fetchTodayCarePlan()
                await viewModel.fetchTimeline()
            }
            .sheet(isPresented: $showingMeasurementSheet) {
                measurementSheet
            }
            .sheet(isPresented: $showingSelfRecord) { SelfRecordSheet(viewModel: viewModel) }
        }
    }
    
    private var progressHeader: some View {
        let completed = viewModel.tasks.filter { $0.status == .COMPLETED }.count
        let total = viewModel.tasks.count
        let percent = total > 0 ? Double(completed) / Double(total) : 0
        
        return VStack {
            HStack {
                Text("Daily Progress")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(completed) of \(total) completed")
                    .font(.subheadline).bold()
            }
            ProgressView(value: percent)
                .tint(.green)
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var nextActionTask: CarePlanOccurrenceDTO? {
        viewModel.tasks.first { $0.status == .DUE || $0.status == .UPCOMING }
    }
    
    private func nextActionCard(task: CarePlanOccurrenceDTO) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Next Action")
                .font(.caption).bold()
                .foregroundColor(.blue)
                .textCase(.uppercase)
            
            Text(task.title)
                .font(.title3).bold()
            
            Text(task.instruction)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                Image(systemName: "clock")
                Text("Due at \(task.due_time)")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            
            Button(action: {
                handleTaskAction(task)
            }) {
                Text(actionTitle(for: task))
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("No active care plan")
                .font(.headline)
            Text("Your care team hasn't assigned daily monitoring or activities yet.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try Again") {
                Task { await viewModel.fetchTodayCarePlan() }
            }
            .padding(.top)
        }
    }

    private func errorStateView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 42))
                .foregroundColor(.orange)
            Text("Care Plan unavailable").font(.headline)
            Text(message).font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
            Button("Try Again") { Task { await viewModel.fetchTodayCarePlan(); await viewModel.fetchTimeline() } }
                .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }
    
    private func taskRow(_ occurrence: CarePlanOccurrenceDTO) -> some View {
        let isDone = occurrence.status == .COMPLETED
        let isMissed = occurrence.status == .MISSED
        let isSkipped = occurrence.status == .SKIPPED
        
        return HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(isDone ? Color.green : (isMissed ? Color.red.opacity(0.2) : Color.blue.opacity(0.1)))
                    .frame(width: 40, height: 40)
                
                Image(systemName: iconFor(type: occurrence.task_type))
                    .foregroundColor(isDone ? .white : (isMissed ? .red : .blue))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(occurrence.title)
                    .font(.headline)
                    .strikethrough(isDone || isSkipped, color: .secondary)
                Text(occurrence.instruction)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                if let val = occurrence.recorded_value {
                    Text("Recorded: \(String(format: "%.1f", val)) \(occurrence.target_unit ?? "")")
                        .font(.caption).bold()
                        .foregroundColor(.green)
                }
            }
            Spacer()
            
            VStack(alignment: .trailing) {
                Text(occurrence.due_time)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if isDone {
                    Text("Done")
                        .font(.caption2).bold()
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .foregroundColor(.green)
                        .cornerRadius(4)
                } else if isSkipped {
                    Text("Skipped")
                        .font(.caption2).bold()
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.gray.opacity(0.2))
                        .foregroundColor(.gray)
                        .cornerRadius(4)
                } else if isMissed {
                    Text("Missed")
                        .font(.caption2).bold()
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.red.opacity(0.2))
                        .foregroundColor(.red)
                        .cornerRadius(4)
                } else {
                    if occurrence.task_type == .MEDICATION || occurrence.task_type == .INSULIN {
                        Menu("Action") {
                            Button("Mark Taken") { submit(occurrence, status: "TAKEN") }
                            Button("Skip", role: .destructive) { submit(occurrence, status: "SKIPPED") }
                        }
                        .font(.caption).bold().buttonStyle(.borderedProminent)
                    } else {
                        Button("Action") { handleTaskAction(occurrence) }
                            .font(.caption).bold().buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func iconFor(type: CarePlanTaskType) -> String {
        switch type {
        case .MEASUREMENT: return "drop.fill"
        case .ACTIVITY: return "figure.walk"
        case .MEDICATION: return "pills.fill"
        case .INSULIN: return "cross.vial.fill"
        }
    }
    
    private func actionTitle(for occurrence: CarePlanOccurrenceDTO) -> String {
        switch occurrence.task_type {
        case .MEASUREMENT: return "Record Reading"
        case .ACTIVITY: return "Mark Completed"
        case .MEDICATION, .INSULIN: return "Mark Taken"
        }
    }
    
    private func handleTaskAction(_ occurrence: CarePlanOccurrenceDTO) {
        if occurrence.task_type == .MEASUREMENT {
            selectedTask = occurrence
            viewModel.errorMessage = nil
            measurementValue = ""
            measurementNote = ""
            showingMeasurementSheet = true
        } else {
            submit(occurrence, status: occurrence.task_type == .ACTIVITY ? "COMPLETED" : "TAKEN")
        }
    }

    private func submit(_ occurrence: CarePlanOccurrenceDTO, status: String) {
        let payload = RecordAdherencePayload(__v: occurrence.__v, date: occurrence.occurrence_date, status: status, value: nil, unit: nil, note: nil)
        Task { _ = await viewModel.recordAdherence(resourceId: occurrence.id, payload: payload) }
    }
    
    private var measurementSheet: some View {
        NavigationView {
            Form {
                if let error = viewModel.errorMessage {
                    Section {
                        Text(error).foregroundColor(.red)
                    }
                }
                if let task = selectedTask {
                    Section(header: Text("Details")) {
                        Text(task.title).font(.headline)
                        Text(task.instruction).font(.subheadline).foregroundColor(.secondary)
                    }
                    
                    Section(header: Text("Reading")) {
                        HStack {
                            TextField("Value", text: $measurementValue)
                                .keyboardType(.decimalPad)
                            if let unit = task.target_unit {
                                Text(unit).foregroundColor(.secondary)
                            }
                        }
                        TextField("Optional Note", text: $measurementNote)
                    }
                }
            }
            .navigationTitle("Record Measurement")
            .navigationBarItems(
                leading: Button("Cancel") { showingMeasurementSheet = false },
                trailing: Button("Save") {
                    if let occ = selectedTask, let val = Double(measurementValue) {
                        let payload = RecordAdherencePayload(__v: occ.__v, date: occ.occurrence_date, status: "RECORDED", value: val, unit: occ.target_unit, note: measurementNote.isEmpty ? nil : measurementNote)
                        Task {
                            // Only close the sheet once the reading has actually been saved.
                            if await viewModel.recordAdherence(resourceId: occ.id, payload: payload) {
                                showingMeasurementSheet = false
                            }
                        }
                    }
                }.disabled(Double(measurementValue) == nil)
            )
        }
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity").font(.headline)
            ForEach(viewModel.timeline.prefix(8)) { event in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(event.title ?? event.task_type?.rawValue.capitalized ?? "Care Plan update").font(.subheadline).bold()
                        Text(event.status.capitalized).font(.caption).foregroundColor(.secondary)
                        if let value = event.observation?.components?.first {
                            Text("\(String(format: "%.1f", value.numeric_value)) \(value.unit)").font(.caption).foregroundColor(.green)
                        }
                    }
                    Spacer()
                    Text(event.occurrence_date).font(.caption2).foregroundColor(.secondary)
                }
                .padding(12)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(10)
            }
        }
        .padding(.horizontal)
    }

    private var selfRecordSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Patient self-recorded").font(.headline)
            ForEach(viewModel.selfRecords.prefix(10)) { record in
                VStack(alignment: .leading, spacing: 3) {
                    Text(record.record_type.replacingOccurrences(of: "_", with: " ").capitalized).font(.subheadline).bold()
                    if record.record_type == "ACTIVITY" { Text("\(record.activity_name ?? "Activity") · \(record.duration_minutes ?? 0) min") }
                    else if record.record_type == "BLOOD_PRESSURE" { Text("\(record.numeric_value ?? 0, specifier: "%.0f")/\(record.secondary_numeric_value ?? 0, specifier: "%.0f") mmHg") }
                    else { Text("\(record.numeric_value ?? 0, specifier: "%.1f") \(record.unit ?? "")") }
                    Text("Patient self-recorded · \(ISODate.display(record.observed_at))").font(.caption).foregroundColor(.secondary)
                }.padding(12).frame(maxWidth: .infinity, alignment: .leading).background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(10)
            }
        }.padding(.horizontal)
    }
}
