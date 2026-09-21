import SwiftUI
import ChettinadCore

struct StaffMainView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            if appState.role == "DOCTOR" {
                DoctorMainView()
            } else if appState.role == "NURSE" {
                NurseMainView()
            } else if appState.role == "ADMIN" {
                AdminMainView()
            } else {
                Text("Unknown role: \(appState.role)")
                Button("Logout", role: .destructive) {
                    appState.logout()
                }
            }
        }
    }
}

struct DoctorMainView: View {
    @EnvironmentObject var appState: AppState
    var body: some View {
        NavigationView {
            VStack {
                Text("Doctor Command Center")
                Button("Logout", role: .destructive) {
                    appState.logout()
                }
            }
            .navigationTitle("Doctor")
        }
    }
}

struct NurseMainView: View {
    @EnvironmentObject var appState: AppState
    var body: some View {
        NavigationView {
            VStack {
                Text("Nurse Triage Queue")
                Button("Logout", role: .destructive) {
                    appState.logout()
                }
            }
            .navigationTitle("Nurse")
        }
    }
}

struct AdminMainView: View {
    @EnvironmentObject var appState: AppState
    var body: some View {
        NavigationView {
            VStack {
                Text("Admin Dashboard")
                Button("Logout", role: .destructive) {
                    appState.logout()
                }
            }
            .navigationTitle("Admin")
        }
    }
}
