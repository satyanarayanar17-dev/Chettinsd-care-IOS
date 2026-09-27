import SwiftUI
import ChettinadCore
import QuickLook

struct PatientCarePlanMonitoringView: View {
    let patientId: String
    let role: String // "DOCTOR" or "NURSE"
    
    @State private var tasks: [CarePlanOccurrenceDTO] = []
    @State private var timeline: [AdherenceResponseDTO] = []
    @State private var selfRecords: [PatientSelfRecord] = []
    @State private var documents: [PatientDocument] = []
    @State private var previewURL: URL?
    @State private var lastPreviewURL: URL?
    @State private var isLoading = true
    @State private var errorMessage: String? = nil
    
    let apiClient = APIClient()
    
    var body: some View {
        VStack(alignment: .leading, spacing: StitchSpacing.lg) {
            Text("Active Care Plan")
                .font(.title2).bold()
                .padding(.horizontal)
            
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if let error = errorMessage {
                VStack(spacing: StitchSpacing.md) {
                    StitchErrorState(message: error)
                    Button("Try Again") { Task { await fetchCarePlan() } }
                }.frame(maxWidth: .infinity).padding()
            } else if tasks.isEmpty {
                Text("No active care plan tasks found for today.")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                let completed = tasks.filter { $0.status == .COMPLETED }.count
                let total = tasks.count
                let progress = total > 0 ? Double(completed)/Double(total) : 0
                
                VStack(spacing: StitchSpacing.sm) {
                    HStack {
                        Text("Today's Adherence")
                            .font(Typography.titleMedium)
                        Spacer()
                        Text("\(completed)/\(total)")
                            .font(Typography.bodyLarge).bold()
                    }
                    ProgressView(value: progress)
                        .tint(progress >= 1.0 ? .green : .blue)
                }
                .padding()
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: StitchSpacing.md) {
                    ForEach(tasks) { occurrence in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(occurrence.title).font(Typography.titleMedium)
                                Text(occurrence.instruction).font(.caption).foregroundColor(.secondary)
                                if let obs = occurrence.recorded_value {
                                    Text("Recorded: \(String(format: "%.1f", obs)) \(occurrence.target_unit ?? "")").font(.caption).bold().foregroundColor(.green)
                                }
                                if occurrence.medication_source?.outdated == true {
                                    Text("Prescription updated — clinician review required").font(.caption2).foregroundColor(.orange)
                                }
                            }
                            Spacer()
                            Text(occurrence.status.rawValue)
                                .font(.caption2).bold()
                                .padding(4)
                                .background(statusColor(occurrence.status).opacity(0.2))
                                .foregroundColor(statusColor(occurrence.status))
                                .cornerRadius(4)
                        }
                        .padding()
                        .background(Color(UIColor.secondarySystemGroupedBackground))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                
                // Timeline snippet
                if !timeline.isEmpty {
                    Text("Recent Activity")
                        .font(Typography.titleMedium)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    VStack(alignment: .leading, spacing: StitchSpacing.md) {
                        ForEach(timeline.prefix(5)) { event in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(event.status).font(Typography.bodyLarge).bold()
                                    if let obs = event.observation?.components?.first?.numeric_value {
                                        Text("Value: \(String(format: "%.1f", obs))").font(.caption).foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Text(ISODate.display(event.recorded_at))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal)
                }

                if !selfRecords.isEmpty {
                    Text("Patient self-recorded observations").font(Typography.titleMedium).padding(.horizontal).padding(.top)
                    VStack(spacing: StitchSpacing.sm) {
                        ForEach(selfRecords.prefix(10)) { record in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(record.record_type.replacingOccurrences(of: "_", with: " ").capitalized).font(Typography.bodyLarge).bold()
                                if record.record_type == "ACTIVITY" { Text("\(record.activity_name ?? "Activity") · \(record.duration_minutes ?? 0) min") }
                                else if record.record_type == "BLOOD_PRESSURE" { Text("\(record.numeric_value ?? 0, specifier: "%.0f")/\(record.secondary_numeric_value ?? 0, specifier: "%.0f") mmHg") }
                                else { Text("\(record.numeric_value ?? 0, specifier: "%.1f") \(record.unit ?? "")") }
                                Text("Patient self-recorded · \(ISODate.display(record.observed_at))").font(.caption2).foregroundColor(.secondary)
                            }.frame(maxWidth: .infinity, alignment: .leading).padding().background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(8)
                        }
                    }.padding(.horizontal)
                }

                if !documents.isEmpty {
                    Text("Patient documents").font(Typography.titleMedium).padding(.horizontal).padding(.top)
                    VStack(spacing: StitchSpacing.sm) { ForEach(documents) { document in Button { Task { previewURL = try? await apiClient.downloadPatientDocument(document) } } label: { HStack { Image(systemName: document.mime_type == "application/pdf" ? "doc.richtext" : "photo"); VStack(alignment: .leading) { Text(document.title).font(Typography.bodyLarge).bold(); Text("\(document.document_type.replacingOccurrences(of: "_", with: " ").capitalized) · \(document.clinical_date) · Patient uploaded").font(.caption2).foregroundColor(.secondary) }; Spacer(); Image(systemName: "eye") }.padding().background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(8) }.buttonStyle(.plain) } }.padding(.horizontal)
                }
            }
        }
        .task {
            await fetchCarePlan()
        }
        .quickLookPreview($previewURL)
        .onChange(of: previewURL) { newValue in
            // Delete the downloaded copy of the document once the preview is dismissed.
            if let old = lastPreviewURL, old != newValue { try? FileManager.default.removeItem(at: old) }
            lastPreviewURL = newValue
        }
    }
    
    private func fetchCarePlan() async {
        isLoading = true
        errorMessage = nil
        do {
            async let fetchedTasks: [CarePlanOccurrenceDTO] = apiClient.execute(endpoint: GetTodayAdherenceEndpoint(patientId: patientId))
            async let fetchedTimeline: [AdherenceResponseDTO] = apiClient.execute(endpoint: GetTimelineEndpoint(patientId: patientId))
            async let fetchedSelfRecords: [PatientSelfRecord] = apiClient.execute(endpoint: PatientSelfRecordsEndpoint(patientId: patientId))
            async let fetchedDocuments: [PatientDocument] = apiClient.execute(endpoint: PatientDocumentsEndpoint(patientId: patientId))
            
            self.tasks = try await fetchedTasks
            self.timeline = try await fetchedTimeline
            self.selfRecords = try await fetchedSelfRecords
            self.documents = try await fetchedDocuments
        } catch {
            self.errorMessage = "The Care Plan could not be loaded. Please try again."
        }
        isLoading = false
    }
    
    private func statusColor(_ status: CarePlanOccurrenceStatus) -> Color {
        switch status {
        case .COMPLETED: return .green
        case .MISSED: return .red
        case .SKIPPED: return .gray
        case .DUE, .UPCOMING: return .blue
        }
    }
}
