import SwiftUI
import ChettinadCore

struct DoctorQueueView: View {
    @StateObject private var viewModel = DoctorQueueViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                AppHeader(title: "Command Center")
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // Welcome
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Welcome, Doctor")
                                .textStyle(Typography.headlineMedium, color: .chettinadPrimary)
                            Text("Outpatient Department")
                                .textStyle(Typography.bodyMedium, color: .chettinadSecondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        
                        // Metrics
                        if let metrics = viewModel.metrics {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: StitchSpacing.lg) {
                                    MetricsCard(title: "Requires Action", value: "\(metrics.requires_action)", iconName: "exclamationmark.triangle.fill", trend: nil)
                                        .frame(width: 160)
                                    MetricsCard(title: "Confirmed Today", value: "\(metrics.today_confirmed)", iconName: "calendar.badge.clock", trend: nil)
                                        .frame(width: 160)
                                    MetricsCard(title: "Waiting", value: "\(metrics.waiting)", iconName: "person.3.sequence.fill", trend: nil)
                                        .frame(width: 160)
                                    MetricsCard(title: "Completed", value: "\(metrics.completed)", iconName: "checkmark.circle.fill", trend: nil)
                                        .frame(width: 160)
                                }
                                .padding(.horizontal, 16)
                            }
                        } else {
                            ProgressView().padding()
                        }
                        
                        // Queue
                        VStack(alignment: .leading, spacing: StitchSpacing.md) {
                            Text("Current Queue")
                                .textStyle(Typography.titleMedium, color: .chettinadPrimary)
                                .padding(.horizontal, 16)
                            
                            if viewModel.isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else if viewModel.queue.isEmpty {
                                VStack(spacing: StitchSpacing.md) {
                                    Image(systemName: "person.3.sequence").font(.system(size: 40)).foregroundColor(.secondary)
                                    Text("No patients currently waiting").font(Typography.titleMedium)
                                    Text("Your OBST patient queue will appear here\nas patients check in.").font(Typography.bodyLarge).foregroundColor(.secondary).multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 40)
                            } else {
                                ForEach(viewModel.queue, id: \.id) { entry in
                                    NavigationLink(destination: PatientDossierView(viewModel: DoctorConsultationViewModel(encounterId: entry.encounter_id, patientId: entry.patient_id, initialVersion: entry.__v), patientName: entry.patient_name)) {
                                        QueueCard(entry: entry)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.bottom, 24)
                }
                .background(Color.chettinadBackground)
                .refreshFromHospital {
                    await viewModel.fetchQueue()
                }
                .refreshable {
                    await viewModel.fetchQueue()
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct NurseTriageView: View {
    @StateObject private var viewModel = NurseTriageViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                AppHeader(title: "Nurse Triage")
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Awaiting Triage")
                                .textStyle(Typography.titleMedium, color: .chettinadSecondary)
                            Text("Emergency & OPD")
                                .textStyle(Typography.headlineMedium, color: .chettinadPrimary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)


                        // Metrics
                        if let metrics = viewModel.metrics {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: StitchSpacing.lg) {
                                    MetricsCard(title: "Requires Action", value: "\(metrics.requires_action)", iconName: "exclamationmark.triangle.fill", trend: nil)
                                        .frame(width: 160)
                                    MetricsCard(title: "Confirmed Today", value: "\(metrics.today_confirmed)", iconName: "calendar.badge.clock", trend: nil)
                                        .frame(width: 160)
                                    MetricsCard(title: "Awaiting Triage", value: "\(metrics.triage)", iconName: "cross.case.fill", trend: nil)
                                        .frame(width: 160)
                                    MetricsCard(title: "Waiting Doctor", value: "\(metrics.waiting)", iconName: "person.3.sequence.fill", trend: nil)
                                        .frame(width: 160)
                                }
                                .padding(.horizontal, 16)
                            }
                        } else {
                            ProgressView().padding()
                        }



                        
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if viewModel.queue.isEmpty {
                            VStack(spacing: StitchSpacing.md) {
                                Image(systemName: "cross.case.fill").font(.system(size: 40)).foregroundColor(.secondary)
                                Text("No patients to triage").font(Typography.titleMedium)
                                Text("Your OBST triage queue will appear here\nas patients check in.").font(Typography.bodyLarge).foregroundColor(.secondary).multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 40)
                        } else {
                            ForEach(viewModel.queue, id: \.id) { entry in
                                NavigationLink(destination: TriageFormView(viewModel: TriageFormViewModel(encounterId: entry.encounter_id, initialVersion: entry.__v), patientId: entry.patient_id, patientName: entry.patient_name)) {
                                    QueueCard(entry: entry)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .background(Color.chettinadBackground)
                .refreshFromHospital {
                    await viewModel.fetchQueue()
                }
                .refreshable {
                    await viewModel.fetchQueue()
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct QueueCard: View {
    let entry: QueueEntry
    
    var body: some View {
        HStack(spacing: StitchSpacing.lg) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.patient_name)
                        .textStyle(Typography.titleMedium, color: .chettinadPrimary)
                    
                    Text(entry.status)
                        .textStyle(Typography.labelSmall, color: entry.status == "WAITING" ? .chettinadWarning : .chettinadSuccess)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(entry.status == "WAITING" ? Color.chettinadWarningContainer : Color.chettinadSuccessContainer)
                        .cornerRadius(8)
                }
                
                Text("Encounter ID: \(entry.id.prefix(8))")
                    .textStyle(Typography.bodySmall, color: .chettinadSecondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.chettinadSecondary)
        }
        .padding(StitchSpacing.lg)
        .background(Color.surfaceContainerLowest)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// AdminStaffListView was removed because it's replaced by AdminDashboardView
import Foundation
import ChettinadCore

@MainActor
class StaffPatientTrendsViewModel: ObservableObject {
    @Published var timeline: [AdherenceResponseDTO] = []
    @Published var selfRecords: [PatientSelfRecord] = []
    @Published var isLoading = true
    @Published var trendsError: String?
    
    let patientId: String
    private let apiClient = APIClient()
    
    init(patientId: String) {
        self.patientId = patientId
    }
    
    func fetchTimeline() async {
        isLoading = true
        trendsError = nil
        do {
            async let timelineTask: [AdherenceResponseDTO] = try await apiClient.execute(endpoint: GetTimelineEndpoint(patientId: patientId))
            async let selfRecordsTask: [PatientSelfRecord] = try await apiClient.execute(endpoint: PatientSelfRecordsEndpoint(patientId: patientId))
            
            let (fetchedTimeline, fetchedSelfRecords) = try await (timelineTask, selfRecordsTask)
            self.timeline = fetchedTimeline
            self.selfRecords = fetchedSelfRecords
        } catch {
            trendsError = error.localizedDescription
        }
        isLoading = false
    }
}
import SwiftUI
import Charts
import ChettinadCore

struct StaffPatientTrendsView: View {
    init(patientId: String) {
        _viewModel = StateObject(wrappedValue: StaffPatientTrendsViewModel(patientId: patientId))
    }
    @StateObject var viewModel: StaffPatientTrendsViewModel
    @State private var timeRange: Int = 30 // Days
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Picker("Time Range", selection: $timeRange) {
                        Text("7 Days").tag(7)
                        Text("30 Days").tag(30)
                        Text("90 Days").tag(90)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    if viewModel.isLoading {
                        ProgressView().padding()
                    } else if let error = viewModel.trendsError, viewModel.timeline.isEmpty, viewModel.selfRecords.isEmpty {
                        Text(error)
                            .foregroundColor(.chettinadError)
                            .padding()
                    } else if filteredTimeline.isEmpty && filteredSelfRecords.isEmpty {
                        Text("No data available for this time range.")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        glucoseSection
                        insulinSection
                        medicationSection
                        activitySection
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("History & Trends")
            .background(Color(UIColor.systemGroupedBackground))
            .task {
                if viewModel.timeline.isEmpty {
                    await viewModel.fetchTimeline()
                }
            }
            .refreshable {
                await viewModel.fetchTimeline()
            }
        }
    }
    
    // MARK: - Filter Logic
    
    private var cutoffDate: Date {
        Calendar.current.date(byAdding: .day, value: -timeRange, to: Date()) ?? Date()
    }
    
    private var filteredTimeline: [AdherenceResponseDTO] {
        return viewModel.timeline.filter { event in
            guard let date = ISODate.parse(event.recorded_at) else { return false }
            return date >= cutoffDate
        }
    }
    
    private var filteredSelfRecords: [PatientSelfRecord] {
        return viewModel.selfRecords.filter { record in
            guard let date = ISODate.parse(record.observed_at) else { return false }
            return date >= cutoffDate
        }
    }
    
    // MARK: - Derived Data
    
    struct ChartData: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }
    
    private var glucoseData: [ChartData] {
        
        // From adherence (Care Plan tasks)
        let scheduled = filteredTimeline.compactMap { event -> ChartData? in
            guard event.task_type == .MEASUREMENT,
                  let target = event.observation_type, target.lowercased().contains("sugar") || target.lowercased().contains("glucose"),
                  let obs = event.observation?.components?.first?.numeric_value,
                  let date = ISODate.parse(event.recorded_at) else { return nil }
            return ChartData(date: date, value: obs)
        }
        
        // From self records
        let selfRecs = filteredSelfRecords.compactMap { record -> ChartData? in
            // The self-record sheet saves "GLUCOSE"; accept the legacy "BLOOD_SUGAR" too.
            guard record.record_type == "GLUCOSE" || record.record_type == "BLOOD_SUGAR",
                  let val = record.numeric_value,
                  let date = ISODate.parse(record.observed_at) else { return nil }
            return ChartData(date: date, value: val)
        }
        
        return (scheduled + selfRecs).sorted { $0.date < $1.date }
    }
    
    private var insulinRecords: [AdherenceResponseDTO] {
        filteredTimeline.filter { $0.task_type == .INSULIN }.sorted { sortDate($0.recorded_at) > sortDate($1.recorded_at) }
    }
    
    private var medicationRecords: [AdherenceResponseDTO] {
        filteredTimeline.filter { $0.task_type == .MEDICATION }.sorted { sortDate($0.recorded_at) > sortDate($1.recorded_at) }
    }
    
    private var activityRecords: [AdherenceResponseDTO] {
        filteredTimeline.filter { $0.task_type == .ACTIVITY }.sorted { sortDate($0.recorded_at) > sortDate($1.recorded_at) }
    }
    
    private var selfActivityRecords: [PatientSelfRecord] {
        filteredSelfRecords.filter { $0.record_type == "ACTIVITY" }.sorted { sortDate($0.observed_at) > sortDate($1.observed_at) }
    }
    
    // MARK: - Views
    
    private var glucoseSection: some View {
        VStack(alignment: .leading, spacing: StitchSpacing.md) {
            Text("Glucose / Blood Sugar").font(Typography.titleMedium).padding(.horizontal)
            if glucoseData.isEmpty {
                Text("No readings in this period.").font(Typography.bodyLarge).foregroundColor(.secondary).padding(.horizontal)
            } else {
                Chart(glucoseData) { item in
                    LineMark(
                        x: .value("Date", item.date),
                        y: .value("Level", item.value)
                    )
                    .symbol(Circle())
                    .interpolationMethod(.monotone)
                }
                .frame(height: 200)
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Table
                VStack(spacing: 0) {
                    ForEach(glucoseData.reversed().prefix(5)) { item in
                        HStack {
                            Text(item.date, format: .dateTime.month().day().hour().minute())
                                .font(Typography.bodyLarge)
                            Spacer()
                            Text("\(String(format: "%.1f", item.value)) mg/dL")
                                .font(Typography.bodyLarge).bold()
                        }
                        .padding()
                        Divider()
                    }
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }
    
    private var insulinSection: some View {
        VStack(alignment: .leading, spacing: StitchSpacing.md) {
            Text("Insulin Adherence").font(Typography.titleMedium).padding(.horizontal)
            if insulinRecords.isEmpty {
                Text("No insulin records.").font(Typography.bodyLarge).foregroundColor(.secondary).padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(insulinRecords.prefix(5)) { record in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(record.title ?? "Insulin").font(Typography.bodyLarge).bold()
                                Text(formatDate(record.recorded_at)).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            statusBadge(record.status)
                        }
                        .padding()
                        Divider()
                    }
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }
    
    private var medicationSection: some View {
        VStack(alignment: .leading, spacing: StitchSpacing.md) {
            Text("Medication History").font(Typography.titleMedium).padding(.horizontal)
            if medicationRecords.isEmpty {
                Text("No medication records.").font(Typography.bodyLarge).foregroundColor(.secondary).padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(medicationRecords.prefix(5)) { record in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(record.title ?? "Medication").font(Typography.bodyLarge).bold()
                                Text(formatDate(record.recorded_at)).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            statusBadge(record.status)
                        }
                        .padding()
                        Divider()
                    }
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }
    
    private var activitySection: some View {
        VStack(alignment: .leading, spacing: StitchSpacing.md) {
            Text("Activity History").font(Typography.titleMedium).padding(.horizontal)
            if activityRecords.isEmpty && selfActivityRecords.isEmpty {
                Text("No activity records.").font(Typography.bodyLarge).foregroundColor(.secondary).padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    // Combine and sort
                    let combined: [(title: String, date: String, status: String?, mins: Int?)] = (
                        activityRecords.map { ($0.title ?? "Activity", $0.recorded_at, $0.status, nil) } +
                        selfActivityRecords.map { ($0.activity_name ?? "Activity", $0.observed_at, "RECORDED", $0.duration_minutes) }
                    ).sorted { sortDate($0.date) > sortDate($1.date) }
                    
                    ForEach(Array(combined.prefix(5).enumerated()), id: \.offset) { _, item in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(item.title).font(Typography.bodyLarge).bold()
                                Text(formatDate(item.date)).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            if let status = item.status {
                                if status == "RECORDED", let mins = item.mins {
                                    Text("\(mins) min").font(.caption).bold().padding(4).background(Color.blue.opacity(0.2)).foregroundColor(.blue).cornerRadius(4)
                                } else {
                                    statusBadge(status)
                                }
                            }
                        }
                        .padding()
                        Divider()
                    }
                }
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
            }
        }
    }
    
    private func statusBadge(_ status: String) -> some View {
        let color: Color
        switch status.uppercased() {
        case "COMPLETED", "TAKEN": color = .green
        case "MISSED": color = .red
        case "SKIPPED": color = .gray
        default: color = .blue
        }
        return Text(status.capitalized)
            .font(.caption2).bold()
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(4)
    }
    
    private func formatDate(_ dateStr: String) -> String {
        ISODate.display(dateStr)
    }

    private func sortDate(_ dateStr: String) -> Date {
        ISODate.parse(dateStr) ?? .distantPast
    }
}
