#!/bin/bash
cat << 'INNER_EOF' > /tmp/PatientDashboardView.swift.replacement
struct PatientDashboardView: View {
    @EnvironmentObject var viewModel: PatientViewModel
    let onAppointments: () -> Void
    let onRecords: () -> Void
    let onCarePlan: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            AppHeader(title: "Chettinad Care")
            
            ScrollView {
                if viewModel.isLoading {
                    ProgressView("Loading Dashboard...")
                        .padding()
                } else if let error = viewModel.errorMessage, viewModel.recordBundle == nil {
                    Text(error).foregroundColor(.chettinadError).padding()
                } else if let bundle = viewModel.recordBundle {
                    VStack(alignment: .leading, spacing: 24) {
                        
                        // Greeting
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Welcome,")
                                .textStyle(Typography.titleMedium, color: .chettinadSecondary)
                            Text(bundle.patient.name)
                                .textStyle(Typography.headlineMedium, color: .chettinadPrimary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        
                        // Next Appointment
                        if let nextApt = viewModel.appointments.filter({ !["COMPLETED", "CANCELLED", "NO_SHOW"].contains($0.status) && (ISODate.parse($0.scheduled_at).map { d in d >= Date() } ?? false) }).sorted(by: { $0.scheduled_at < $1.scheduled_at }).first {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Next Appointment").font(.headline)
                                    Spacer()
                                    Button("View all", action: onAppointments).font(.caption)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(nextApt.doctor_name ?? "Obstetrics & Gynaecology").font(.headline)
                                    Text(ISODate.display(nextApt.scheduled_at)).font(.subheadline).foregroundColor(.secondary)
                                    Text(nextApt.status == "PENDING_CONFIRMATION" ? "Awaiting confirmation" : nextApt.status.replacingOccurrences(of: "_", with: " ")).font(.caption).bold().foregroundColor(.blue)
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(12)
                            }
                            .padding(.horizontal, 16)
                        }
                        
                        // Today's Care Plan
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Today's Care Plan").font(.headline)
                                Spacer()
                                Button("Open", action: onCarePlan).font(.caption)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                if viewModel.todayCareTasks.isEmpty {
                                    Text("No tasks scheduled for today.").foregroundColor(.secondary).font(.subheadline)
                                } else {
                                    let completed = viewModel.todayCareTasks.filter { $0.status == .COMPLETED || $0.status == .SKIPPED || $0.status == .MISSED }.count
                                    Text("\(completed) of \(viewModel.todayCareTasks.count) tasks completed").font(.subheadline).bold()
                                    ProgressView(value: Double(completed), total: Double(max(viewModel.todayCareTasks.count, 1)))
                                    
                                    if let nextDue = viewModel.todayCareTasks.first(where: { $0.status == .DUE || $0.status == .UPCOMING }) {
                                        Text("Next due: \(nextDue.title) at \(nextDue.scheduled_time)").font(.caption).foregroundColor(.secondary)
                                    } else if completed == viewModel.todayCareTasks.count {
                                        Text("All caught up for today!").font(.caption).foregroundColor(.green)
                                    }
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 16)
                        
                        // Quick Actions
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Quick Actions").font(.headline).padding(.horizontal, 16)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                Button(action: onAppointments) {
                                    VStack(spacing: 8) {
                                        Image(systemName: "calendar.badge.plus").font(.title2)
                                        Text("Book").font(.subheadline)
                                    }
                                    .frame(maxWidth: .infinity).padding().background(Color(.secondarySystemBackground)).cornerRadius(12)
                                }.buttonStyle(.plain)
                                
                                Button(action: onRecords) {
                                    VStack(spacing: 8) {
                                        Image(systemName: "doc.badge.plus").font(.title2)
                                        Text("Upload").font(.subheadline)
                                    }
                                    .frame(maxWidth: .infinity).padding().background(Color(.secondarySystemBackground)).cornerRadius(12)
                                }.buttonStyle(.plain)
                            }.padding(.horizontal, 16)
                        }
                        
                        // Recent
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recent").font(.headline).padding(.horizontal, 16)
                            if let rx = bundle.prescriptions.first {
                                HStack {
                                    Image(systemName: "pills.fill").foregroundColor(.purple)
                                    VStack(alignment: .leading) {
                                        Text("Latest Prescription").font(.subheadline).bold()
                                        Text(String(rx.created_at.prefix(10))).font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding().background(Color(.secondarySystemBackground)).cornerRadius(12).padding(.horizontal, 16)
                            }
                            if let doc = viewModel.documents.first {
                                HStack {
                                    Image(systemName: "doc.text.fill").foregroundColor(.blue)
                                    VStack(alignment: .leading) {
                                        Text("Latest Upload").font(.subheadline).bold()
                                        Text(doc.title).font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding().background(Color(.secondarySystemBackground)).cornerRadius(12).padding(.horizontal, 16)
                            }
                        }
                        .padding(.bottom, 24)
                    }
                }
            }
            .background(Color.chettinadBackground)
            .refreshable {
                await viewModel.fetchRecords()
            }
        }
    }
}
INNER_EOF

# Replace lines 6 to 118 with the new content
sed -i '' -e '6,118c\
'"$(cat /tmp/PatientDashboardView.swift.replacement | sed 's/$/\\/g')"'' ChettinadCarePatient/Features/PatientViews.swift

# Fix the trailing backslash added by the sed trick for the last line
sed -i '' 's/}$/}/' ChettinadCarePatient/Features/PatientViews.swift
