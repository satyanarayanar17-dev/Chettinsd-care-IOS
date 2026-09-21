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
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            MetricsCard(title: "Patients Waiting", value: "\(viewModel.queue.count)", iconName: "person.3.sequence.fill", trend: viewModel.queue.count > 5 ? "High" : "Normal")
                            MetricsCard(title: "Avg Wait Time", value: "18m", iconName: "clock.fill")
                        }
                        .padding(.horizontal, 16)
                        
                        // Queue
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Current Queue")
                                .textStyle(Typography.titleMedium, color: .chettinadPrimary)
                                .padding(.horizontal, 16)
                            
                            if viewModel.isLoading {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding()
                            } else if viewModel.queue.isEmpty {
                                Text("No patients in queue.")
                                    .textStyle(Typography.bodyLarge, color: .chettinadSecondary)
                                    .padding(.horizontal, 16)
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
                .task {
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
                        
                        if viewModel.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else if viewModel.queue.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "cross.case.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.chettinadSecondary.opacity(0.5))
                                Text("No patients currently waiting.")
                                    .textStyle(Typography.bodyLarge, color: .chettinadSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        } else {
                            ForEach(viewModel.queue, id: \.id) { entry in
                                NavigationLink(destination: TriageFormView(viewModel: TriageFormViewModel(encounterId: entry.encounter_id, initialVersion: entry.__v), patientName: entry.patient_name)) {
                                    QueueCard(entry: entry)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
                .background(Color.chettinadBackground)
                .task {
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
        HStack(spacing: 16) {
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
        .padding(16)
        .background(Color.surfaceContainerLowest)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// AdminStaffListView was removed because it's replaced by AdminDashboardView
