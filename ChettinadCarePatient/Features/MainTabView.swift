import SwiftUI
import ChettinadCore

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView {
            PatientDashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "heart.text.square")
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
    }
}
