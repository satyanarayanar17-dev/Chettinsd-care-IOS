import SwiftUI
import ChettinadCore

struct StaffMainView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        Group {
            if appState.role == "DOCTOR" {
                DoctorQueueView()
            } else if appState.role == "NURSE" {
                NurseTriageView()
            } else if appState.role == "ADMIN" {
                AdminStaffListView()
            } else {
                Text("Invalid Role: \(appState.role)")
            }
        }
        .overlay(alignment: .bottom) {
            Button("Logout", role: .destructive) {
                appState.logout()
            }
            .padding()
        }
    }
}
