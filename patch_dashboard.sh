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
                        .padding(StitchSpacing.xxl)
                } else if let error = viewModel.errorMessage, viewModel.recordBundle == nil {
                    StitchErrorState(message: error) {
                        Task { await viewModel.fetchRecords() }
                    }
                    .padding(StitchSpacing.lg)
                } else if let bundle = viewModel.recordBundle {
                    VStack(alignment: .leading, spacing: StitchSpacing.xl) {
                        
                        // Greeting
                        VStack(alignment: .leading, spacing: StitchSpacing.xs) {
                            Text("Welcome,")
                                .textStyle(Typography.titleMedium, color: .chettinadSecondary)
                            Text(bundle.patient.name)
                                .textStyle(Typography.headlineLarge, color: .chettinadPrimary)
                        }
                        .padding(.horizontal, StitchSpacing.lg)
                        .padding(.top, StitchSpacing.lg)
                        
                        // Next Appointment
                        if let nextApt = viewModel.appointments.filter({ !["COMPLETED", "CANCELLED", "NO_SHOW"].contains($0.status) && (ISODate.parse($0.scheduled_at).map { d in d >= Date() } ?? false) }).sorted(by: { $0.scheduled_at < $1.scheduled_at }).first {
                            VStack(alignment: .leading, spacing: StitchSpacing.sm) {
                                HStack {
                                    Text("Next Appointment").font(Typography.titleMedium).foregroundStyle(Color.chettinadTextPrimary)
                                    Spacer()
                                    Button("View all", action: onAppointments).buttonStyle(StitchCompactButtonStyle())
                                }
                                .padding(.horizontal, StitchSpacing.lg)
                                
                                StitchCard {
                                    VStack(alignment: .leading, spacing: StitchSpacing.md) {
                                        Text(nextApt.doctor_name ?? "Obstetrics & Gynaecology").font(Typography.titleMedium).foregroundStyle(Color.chettinadPrimary)
                                        Text(ISODate.display(nextApt.scheduled_at)).font(Typography.bodyLarge).foregroundStyle(Color.chettinadTextSecondary)
                                        StitchStatusChip(status: nextApt.status)
                                    }
                                }
                                .padding(.horizontal, StitchSpacing.lg)
                            }
                        }
                        
                        // Today's Care Plan
                        VStack(alignment: .leading, spacing: StitchSpacing.sm) {
                            HStack {
                                Text("Today's Care Plan").font(Typography.titleMedium).foregroundStyle(Color.chettinadTextPrimary)
                                Spacer()
                                Button("Open", action: onCarePlan).buttonStyle(StitchCompactButtonStyle())
                            }
                            .padding(.horizontal, StitchSpacing.lg)
                            
                            StitchCard {
                                VStack(alignment: .leading, spacing: StitchSpacing.md) {
                                    if viewModel.todayCareTasks.isEmpty {
                                        Text("No tasks scheduled for today.").font(Typography.bodyLarge).foregroundStyle(Color.chettinadTextSecondary)
                                    } else {
                                        let completed = viewModel.todayCareTasks.filter { $0.status == .COMPLETED || $0.status == .SKIPPED || $0.status == .MISSED }.count
                                        Text("\(completed) of \(viewModel.todayCareTasks.count) tasks completed").font(Typography.titleMedium).foregroundStyle(Color.chettinadPrimary)
                                        ProgressView(value: Double(completed), total: Double(max(viewModel.todayCareTasks.count, 1)))
                                            .tint(.chettinadPrimary)
                                        
                                        if let nextDue = viewModel.todayCareTasks.first(where: { $0.status == .DUE || $0.status == .UPCOMING }) {
                                            Text("Next due: \(nextDue.title) at \(nextDue.scheduled_time)").font(Typography.bodyMedium).foregroundStyle(Color.chettinadTextSecondary)
                                        } else if completed == viewModel.todayCareTasks.count {
                                            Text("All caught up for today!").font(Typography.bodyMedium).foregroundStyle(Color.chettinadSuccess)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, StitchSpacing.lg)
                        }
                        
                        // Quick Actions
                        VStack(alignment: .leading, spacing: StitchSpacing.sm) {
                            Text("Quick Actions").font(Typography.titleMedium).foregroundStyle(Color.chettinadTextPrimary).padding(.horizontal, StitchSpacing.lg)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: StitchSpacing.lg) {
                                Button(action: onAppointments) {
                                    VStack(spacing: StitchSpacing.sm) {
                                        Image(systemName: "calendar.badge.plus").font(.system(size: 24, weight: .medium))
                                        Text("Book").font(Typography.labelLarge)
                                    }
                                    .frame(maxWidth: .infinity).padding(StitchSpacing.lg)
                                    .background(Color.chettinadPrimary.opacity(0.1))
                                    .foregroundStyle(Color.chettinadPrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }.buttonStyle(.plain)
                                
                                Button(action: onRecords) {
                                    VStack(spacing: StitchSpacing.sm) {
                                        Image(systemName: "doc.badge.plus").font(.system(size: 24, weight: .medium))
                                        Text("Upload").font(Typography.labelLarge)
                                    }
                                    .frame(maxWidth: .infinity).padding(StitchSpacing.lg)
                                    .background(Color.chettinadPrimary.opacity(0.1))
                                    .foregroundStyle(Color.chettinadPrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }.buttonStyle(.plain)
                            }.padding(.horizontal, StitchSpacing.lg)
                        }
                        
                        // Recent
                        VStack(alignment: .leading, spacing: StitchSpacing.sm) {
                            Text("Recent").font(Typography.titleMedium).foregroundStyle(Color.chettinadTextPrimary).padding(.horizontal, StitchSpacing.lg)
                            if let rx = bundle.prescriptions.first {
                                StitchCard {
                                    HStack(spacing: StitchSpacing.md) {
                                        Image(systemName: "pills.fill").font(.system(size: 24)).foregroundColor(.purple)
                                        VStack(alignment: .leading, spacing: StitchSpacing.xs) {
                                            Text("Latest Prescription").font(Typography.titleSmall).foregroundStyle(Color.chettinadTextPrimary)
                                            Text(String(rx.created_at.prefix(10))).font(Typography.bodyMedium).foregroundStyle(Color.chettinadTextSecondary)
                                        }
                                        Spacer()
                                    }
                                }.padding(.horizontal, StitchSpacing.lg)
                            }
                            if let doc = viewModel.documents.first {
                                StitchCard {
                                    HStack(spacing: StitchSpacing.md) {
                                        Image(systemName: "doc.text.fill").font(.system(size: 24)).foregroundColor(.blue)
                                        VStack(alignment: .leading, spacing: StitchSpacing.xs) {
                                            Text("Latest Upload").font(Typography.titleSmall).foregroundStyle(Color.chettinadTextPrimary)
                                            Text(doc.title).font(Typography.bodyMedium).foregroundStyle(Color.chettinadTextSecondary)
                                        }
                                        Spacer()
                                    }
                                }.padding(.horizontal, StitchSpacing.lg)
                            }
                        }
                        .padding(.bottom, StitchSpacing.xxl)
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

sed -i '' -e '5,174c\
'"$(cat /tmp/PatientDashboardView.swift.replacement | sed 's/$/\\/g')"'' ChettinadCarePatient/Features/PatientViews.swift

sed -i '' 's/}$/}/' ChettinadCarePatient/Features/PatientViews.swift

