import SwiftUI
import ChettinadCore

@main
struct ChettinadCareStaffApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            if appState.isAuthenticated {
                StaffMainView()
                    .environmentObject(appState)
            } else {
                StaffLoginView()
                    .environmentObject(appState)
            }
        }
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var role: String = ""
    
    init() {
        checkSession()
    }
    
    func checkSession() {
        Task {
            if let session = await SessionManager.shared.getSession(), session.role.uppercased() != "PATIENT" {
                self.isAuthenticated = true
                self.role = session.role.uppercased()
            } else {
                self.isAuthenticated = false
            }
        }
    }
    
    func logout() {
        Task {
            await SessionManager.shared.clearSession()
            self.isAuthenticated = false
            self.role = ""
        }
    }
}
