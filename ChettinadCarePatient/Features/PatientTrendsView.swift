import SwiftUI
import Charts
import ChettinadCore

struct PatientTrendsView: View {
    @EnvironmentObject var viewModel: PatientViewModel
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Glucose / Blood Sugar").font(.headline).padding(.horizontal)
            if glucoseData.isEmpty {
                Text("No readings in this period.").font(.subheadline).foregroundColor(.secondary).padding(.horizontal)
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
                                .font(.subheadline)
                            Spacer()
                            Text("\(String(format: "%.1f", item.value)) mg/dL")
                                .font(.subheadline).bold()
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Insulin Adherence").font(.headline).padding(.horizontal)
            if insulinRecords.isEmpty {
                Text("No insulin records.").font(.subheadline).foregroundColor(.secondary).padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(insulinRecords.prefix(5)) { record in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(record.title ?? "Insulin").font(.subheadline).bold()
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Medication History").font(.headline).padding(.horizontal)
            if medicationRecords.isEmpty {
                Text("No medication records.").font(.subheadline).foregroundColor(.secondary).padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(medicationRecords.prefix(5)) { record in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(record.title ?? "Medication").font(.subheadline).bold()
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Activity History").font(.headline).padding(.horizontal)
            if activityRecords.isEmpty && selfActivityRecords.isEmpty {
                Text("No activity records.").font(.subheadline).foregroundColor(.secondary).padding(.horizontal)
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
                                Text(item.title).font(.subheadline).bold()
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
