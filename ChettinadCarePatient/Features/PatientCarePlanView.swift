import SwiftUI
import ChettinadCore

struct PatientCarePlanView: View {
    @StateObject private var viewModel = CarePlanViewModel()
    @State private var showingMeasurementSheet = false
    @State private var selectedTask: CarePlanOccurrenceDTO?
    @State private var measurementValue: String = ""
    @State private var measurementNote: String = ""
    @State private var showingSelfRecord = false
    @State private var showingActivityRecord = false
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.tasks.isEmpty {
                    ProgressView("Loading Care Plan...")
                } else if let error = viewModel.errorMessage, viewModel.tasks.isEmpty {
                    errorStateView(error)
                } else {
                    ScrollView {
                        VStack(spacing: StitchSpacing.lg) {
                            if !viewModel.tasks.isEmpty {
                                progressHeader
                            }

                            if let error = viewModel.errorMessage {
                                Text(error)
                                    .font(.footnote)
                                    .foregroundStyle(Color.chettinadError)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal)
                            }

                            HStack(spacing: StitchSpacing.md) {
                                Button { showingActivityRecord = true } label: { Label("What activity have you done?", systemImage: "figure.run").frame(maxWidth: .infinity).padding(StitchSpacing.md) }
                                    .buttonStyle(StitchPrimaryButtonStyle()).tint(.green)
                                Button { showingSelfRecord = true } label: { Label("Add Vitals", systemImage: "heart.text.square").frame(maxWidth: .infinity).padding(StitchSpacing.md) }
                                    .buttonStyle(StitchPrimaryButtonStyle())
                            }.padding(.horizontal)
                            
                            if viewModel.tasks.isEmpty && !viewModel.isLoading {
                                emptyStateView
                                    .padding(.vertical, 32)
                            } else {
                                if let next = nextActionTask {
                                    nextActionCard(task: next)
                                }
                                
                                VStack(alignment: .leading, spacing: StitchSpacing.md) {
                                    Text("Today's Checklist").font(Typography.titleMedium).padding(.horizontal)
                                    ForEach(viewModel.tasks) { occurrence in
                                        taskRow(occurrence)
                                    }
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
            .sheet(isPresented: $showingActivityRecord) { LogActivitySheet(viewModel: viewModel) }
        }
    }
    
    private var progressHeader: some View {
        let completed = viewModel.tasks.filter { $0.status == .COMPLETED }.count
        let total = viewModel.tasks.count
        let percent = total > 0 ? Double(completed) / Double(total) : 0
        
        return StitchCard {
            HStack {
                Text("Daily Progress")
                    .font(Typography.bodyLarge)
                    .foregroundStyle(Color.chettinadTextSecondary)
                Spacer()
                Text("\(completed) of \(total) completed")
                    .font(Typography.bodyLarge).bold()
            }
            ProgressView(value: percent)
                .tint(.green)
        }
        .padding(.horizontal)
    }
    
    private var nextActionTask: CarePlanOccurrenceDTO? {
        viewModel.tasks.first { $0.status == .DUE || $0.status == .UPCOMING }
    }
    
    private func nextActionCard(task: CarePlanOccurrenceDTO) -> some View {
        StitchCard {
            Text("Next Action")
                .font(Typography.bodyMedium).bold()
                .foregroundColor(.blue)
                .textCase(.uppercase)
            
            Text(task.title)
                .font(Typography.titleMedium).bold()
            
            Text(task.instruction)
                .font(Typography.bodyLarge)
                .foregroundStyle(Color.chettinadTextSecondary)
            
            HStack {
                Image(systemName: "clock")
                Text("Due at \(task.due_time)")
            }
            .font(Typography.bodyMedium)
            .foregroundStyle(Color.chettinadTextSecondary)
            
            Button(action: {
                handleTaskAction(task)
            }) {
                Text(actionTitle(for: task))
            }
            .buttonStyle(StitchPrimaryButtonStyle())
        }
        .padding(.horizontal)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: StitchSpacing.lg) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 48))
                .foregroundColor(.gray)
            Text("No active care plan")
                .font(Typography.titleMedium)
            Text("Your care team hasn't assigned daily monitoring or activities yet.")
                .font(Typography.bodyLarge)
                .foregroundStyle(Color.chettinadTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button("Try Again") {
                Task { await viewModel.fetchTodayCarePlan() }
            }
            .padding(.top)
        }
    }

    private func errorStateView(_ message: String) -> some View {
        StitchErrorState(message: message) {
            Task { await viewModel.fetchTodayCarePlan(); await viewModel.fetchTimeline() }
        }
        .padding(32)
    }
    
    private func taskRow(_ occurrence: CarePlanOccurrenceDTO) -> some View {
        let isDone = occurrence.status == .COMPLETED
        let isMissed = occurrence.status == .MISSED
        let isSkipped = occurrence.status == .SKIPPED
        
        return StitchCard {
            HStack(spacing: StitchSpacing.lg) {
                ZStack {
                    Circle()
                        .fill(isDone ? Color.green : (isMissed ? Color.red.opacity(0.2) : Color.blue.opacity(0.1)))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: iconFor(type: occurrence.task_type))
                        .foregroundColor(isDone ? .white : (isMissed ? .red : .blue))
                }
                
                VStack(alignment: .leading, spacing: StitchSpacing.xs) {
                    Text(occurrence.title)
                        .font(Typography.titleMedium)
                        .strikethrough(isDone || isSkipped, color: .secondary)
                    Text(occurrence.instruction)
                        .font(Typography.bodyLarge)
                        .foregroundStyle(Color.chettinadTextSecondary)
                    
                    if let val = occurrence.recorded_value {
                        Text("Recorded: \(String(format: "%.1f", val)) \(occurrence.target_unit ?? "")")
                            .font(Typography.bodyMedium).bold()
                            .foregroundColor(.green)
                    }
                }
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(occurrence.due_time)
                        .font(Typography.bodyMedium)
                        .foregroundStyle(Color.chettinadTextSecondary)
                    
                    if isDone {
                        StitchStatusChip(status: "COMPLETED")
                    } else if isSkipped {
                        StitchStatusChip(status: "SKIPPED")
                    } else if isMissed {
                        StitchStatusChip(status: "MISSED")
                    } else {
                        if occurrence.task_type == .MEDICATION || occurrence.task_type == .INSULIN {
                            Menu("Action") {
                                Button("Mark Taken") { submit(occurrence, status: "TAKEN") }
                                Button("Skip", role: .destructive) { submit(occurrence, status: "SKIPPED") }
                            }
                            .font(Typography.bodyMedium).bold().buttonStyle(StitchPrimaryButtonStyle())
                        } else {
                            Button("Action") { handleTaskAction(occurrence) }
                                .font(Typography.bodyMedium).bold().buttonStyle(StitchPrimaryButtonStyle())
                        }
                    }
                }
            }
        }
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
                        Text(error).foregroundStyle(Color.chettinadError)
                    }
                }
                if let task = selectedTask {
                    Section(header: Text("Details")) {
                        Text(task.title).font(Typography.titleMedium)
                        Text(task.instruction).font(Typography.bodyLarge).foregroundStyle(Color.chettinadTextSecondary)
                    }
                    
                    Section(header: Text("Reading")) {
                        HStack {
                            TextField("Value", text: $measurementValue)
                                .keyboardType(.decimalPad)
                            if let unit = task.target_unit {
                                Text(unit).foregroundStyle(Color.chettinadTextSecondary)
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
        VStack(alignment: .leading, spacing: StitchSpacing.md) {
            Text("Recent Activity").font(Typography.titleMedium)
            ForEach(viewModel.timeline.prefix(8)) { event in
                StitchCard {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(event.title ?? event.task_type?.rawValue.capitalized ?? "Care Plan update").font(Typography.bodyLarge).bold()
                            Text(event.status.capitalized).font(Typography.bodyMedium).foregroundStyle(Color.chettinadTextSecondary)
                            if let value = event.observation?.components?.first {
                                Text("\(String(format: "%.1f", value.numeric_value)) \(value.unit)").font(Typography.bodyMedium).foregroundColor(.green)
                            }
                        }
                        Spacer()
                        Text(event.occurrence_date).font(Typography.bodySmall).foregroundStyle(Color.chettinadTextSecondary)
                    }
                }
            }
        }
        .padding(.horizontal)
    }

    private var selfRecordSection: some View {
        VStack(alignment: .leading, spacing: StitchSpacing.md) {
            Text("Patient self-recorded").font(Typography.titleMedium)
            ForEach(viewModel.selfRecords.prefix(10)) { record in
                StitchCard {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(record.record_type.replacingOccurrences(of: "_", with: " ").capitalized).font(Typography.bodyLarge).bold()
                        if record.record_type == "ACTIVITY" { Text("\(record.activity_name ?? "Activity") · \(record.duration_minutes ?? 0) min") }
                        else if record.record_type == "BLOOD_PRESSURE" { Text("\(record.numeric_value ?? 0, specifier: "%.0f")/\(record.secondary_numeric_value ?? 0, specifier: "%.0f") mmHg") }
                        else { Text("\(record.numeric_value ?? 0, specifier: "%.1f") \(record.unit ?? "")") }
                        Text("Patient self-recorded · \(ISODate.display(record.observed_at))").font(Typography.bodyMedium).foregroundStyle(Color.chettinadTextSecondary)
                    }
                }
            }
        }.padding(.horizontal)
    }
}
