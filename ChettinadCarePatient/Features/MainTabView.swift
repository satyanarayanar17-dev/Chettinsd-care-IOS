import SwiftUI
import ChettinadCore

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = PatientViewModel()
    @State private var selectedTab = 1
    
    var body: some View {
        TabView(selection: $selectedTab) {
            PatientCarePlanView()
                .tag(0)
                .tabItem {
                    Label("Care Plan", systemImage: "checklist")
                }
            
            PatientDashboardView(onAppointments: { selectedTab = 2 }, onRecords: { selectedTab = 3 }, onCarePlan: { selectedTab = 0 })
                .tag(1)
                .tabItem {
                    Label("Home", systemImage: "house")
                }
            
            PatientQueueView()
                .tag(6)
                .tabItem {
                    Label("Queue", systemImage: "person.3.sequence")
                }
            
            PatientAppointmentsView(onRecords: { selectedTab = 3 })
                .tag(2)
                .tabItem {
                    Label("Appointments", systemImage: "calendar")
                }
            
            PatientRecordsView()
                .tag(3)
                .tabItem {
                    Label("Records", systemImage: "folder.fill")
                }
            
            PatientTrendsView()
                .tag(5)
                .tabItem {
                    Label("Trends", systemImage: "chart.xyaxis.line")
                }
            
            PatientProfileView()
                .tag(4)
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
        .environmentObject(viewModel)
        .task {
            if viewModel.recordBundle == nil {
                await viewModel.fetchRecords()
            }
        }
    }
}
