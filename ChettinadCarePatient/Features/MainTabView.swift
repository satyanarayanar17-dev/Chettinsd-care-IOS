import SwiftUI
import ChettinadCore

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var viewModel = PatientViewModel()
    
    var body: some View {
        TabView {
            PatientDashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "heart.text.square")
                }
            
            PatientAppointmentsView()
                .tabItem {
                    Label("Appointments", systemImage: "calendar")
                }
            
            PatientRecordsView()
                .tabItem {
                    Label("Records", systemImage: "folder.fill")
                }
            
            PatientProfileView()
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
