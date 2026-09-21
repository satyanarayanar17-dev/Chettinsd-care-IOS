import SwiftUI
import ChettinadCore

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    @State private var patientName: String = "Patient"
    
    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "heart.text.square")
                }
            
            RecordsView()
                .tabItem {
                    Label("Records", systemImage: "folder.fill")
                }
            
            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.crop.circle")
                }
        }
        .onAppear {
            if let session = SessionManager.shared.getSession() {
                patientName = session.name ?? "Patient"
            }
        }
    }
}

struct DashboardView: View {
    var body: some View {
        NavigationView {
            Text("Patient Dashboard")
                .navigationTitle("Dashboard")
        }
    }
}

struct RecordsView: View {
    var body: some View {
        NavigationView {
            Text("Clinical Records")
                .navigationTitle("Records")
        }
    }
}

struct ProfileView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Patient Profile")
                
                Button("Logout", role: .destructive) {
                    appState.logout()
                }
                .padding()
            }
            .navigationTitle("Profile")
        }
    }
}
