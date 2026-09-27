import re

with open('ChettinadCareStaff/Features/StaffViews.swift', 'r') as f:
    content = f.read()

# Add appState to DoctorQueueView
if 'struct DoctorQueueView: View {' in content and '@EnvironmentObject var appState: AppState' not in content[:content.find('struct NurseTriageView')]:
    content = content.replace(
        'struct DoctorQueueView: View {\n    @StateObject private var viewModel = DoctorQueueViewModel()',
        'struct DoctorQueueView: View {\n    @EnvironmentObject var appState: AppState\n    @StateObject private var viewModel = DoctorQueueViewModel()'
    )

# Add appState to NurseTriageView
if 'struct NurseTriageView: View {' in content and '@EnvironmentObject var appState: AppState' not in content[content.find('struct NurseTriageView'):]:
    content = content.replace(
        'struct NurseTriageView: View {\n    @StateObject private var viewModel = NurseTriageViewModel()',
        'struct NurseTriageView: View {\n    @EnvironmentObject var appState: AppState\n    @StateObject private var viewModel = NurseTriageViewModel()'
    )

doctor_sections = """
                        // Requires Action
                        if !viewModel.pendingAppointments.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Requires Action")
                                    .textStyle(Typography.titleMedium, color: .chettinadWarning)
                                    .padding(.horizontal, 16)
                                ForEach(viewModel.pendingAppointments) { apt in
                                    AppointmentAdminCard(appointment: apt, onCheckIn: {
                                        Task { await viewModel.checkIn(appointmentId: apt.id) }
                                    }, onConfirm: {
                                        Task { await viewModel.confirmAppointment(appointmentId: apt.id) }
                                    }, role: appState.role)
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                        
                        // Today's Appointments
                        if !viewModel.todayAppointments.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Today's Confirmed")
                                    .textStyle(Typography.titleMedium, color: .chettinadPrimary)
                                    .padding(.horizontal, 16)
                                ForEach(viewModel.todayAppointments) { apt in
                                    AppointmentAdminCard(appointment: apt, onCheckIn: {
                                        Task { await viewModel.checkIn(appointmentId: apt.id) }
                                    }, onConfirm: {
                                        Task { await viewModel.confirmAppointment(appointmentId: apt.id) }
                                    }, role: appState.role)
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                        
                        // Queue
"""

nurse_sections = """
                        // Requires Action
                        if !viewModel.pendingAppointments.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Requires Action")
                                    .textStyle(Typography.titleMedium, color: .chettinadWarning)
                                    .padding(.horizontal, 16)
                                ForEach(viewModel.pendingAppointments) { apt in
                                    AppointmentAdminCard(appointment: apt, onCheckIn: {
                                        Task { await viewModel.checkIn(appointmentId: apt.id) }
                                    }, onConfirm: {
                                        Task { await viewModel.confirmAppointment(appointmentId: apt.id) }
                                    }, role: appState.role)
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                        
                        // Today's Appointments
                        if !viewModel.todayAppointments.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Today's Confirmed")
                                    .textStyle(Typography.titleMedium, color: .chettinadPrimary)
                                    .padding(.horizontal, 16)
                                ForEach(viewModel.todayAppointments) { apt in
                                    AppointmentAdminCard(appointment: apt, onCheckIn: {
                                        Task { await viewModel.checkIn(appointmentId: apt.id) }
                                    }, onConfirm: {
                                        Task { await viewModel.confirmAppointment(appointmentId: apt.id) }
                                    }, role: appState.role)
                                    .padding(.horizontal, 16)
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Current Queue")
                                .textStyle(Typography.titleMedium, color: .chettinadPrimary)
                                .padding(.horizontal, 16)
                            
"""

# Replace DoctorQueueView "// Queue"
doctor_idx = content.find('// Queue\n                        VStack(alignment: .leading, spacing: 12) {\n                            Text("Current Queue")')
if doctor_idx != -1:
    content = content[:doctor_idx] + doctor_sections + content[doctor_idx + len('// Queue\n'):]

# Replace NurseTriageView Queue
nurse_idx = content.find('if viewModel.isLoading {', content.find('struct NurseTriageView'))
if nurse_idx != -1:
    content = content[:nurse_idx] + nurse_sections + content[nurse_idx:]

# NurseTriageView queue block end padding insertion
nurse_end_idx = content.find('.padding(.horizontal, 16)', content.find('ForEach(viewModel.queue, id: \.id)', nurse_idx))
if nurse_end_idx != -1:
    nurse_end_full = content.find('}', nurse_end_idx)
    content = content[:nurse_end_full+1] + '\n                        }' + content[nurse_end_full+1:]

with open('ChettinadCareStaff/Features/StaffViews.swift', 'w') as f:
    f.write(content)

