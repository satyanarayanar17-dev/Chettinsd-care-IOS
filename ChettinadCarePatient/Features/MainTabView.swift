import SwiftUI
import ChettinadCore

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = PatientViewModel()
    @State private var selectedTab = PatientTab.home
    @Environment(\.scenePhase) private var scenePhase

    private enum PatientTab: Hashable {
        case home, carePlan, appointments, records, profile
    }
    
    var body: some View {
        TabView(selection: $selectedTab) {
            PatientDashboardView(onAppointments: { selectedTab = .appointments }, onRecords: { selectedTab = .records }, onCarePlan: { selectedTab = .carePlan })
                .tag(PatientTab.home)
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            
            PatientCarePlanView()
                .tag(PatientTab.carePlan)
                .tabItem {
                    Label("Care Plan", systemImage: "checklist")
                }
            
            PatientAppointmentsView(onRecords: { selectedTab = .records })
                .tag(PatientTab.appointments)
                .tabItem {
                    Label("Appointments", systemImage: "calendar")
                }
            
            PatientRecordsView()
                .tag(PatientTab.records)
                .tabItem {
                    Label("Records", systemImage: "folder.fill")
                }
            
            PatientProfileView()
                .tag(PatientTab.profile)
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
        .environmentObject(viewModel)
        .refreshFromHospital {
            if !viewModel.isSubmitting { await viewModel.fetchRecords(silent: viewModel.recordBundle != nil) }
        }
    }
}
