import SwiftUI
import ChettinadCore

@main
struct ChettinadCareStaffApp: App {
    @StateObject private var appState = AppState()
    
    init() { StitchTheme.registerFonts() }

    var body: some Scene {
        WindowGroup {
            if appState.isAuthenticated {
                StaffMainView()
                    .environmentObject(appState)
                    .tint(.chettinadPrimary)
                    .font(Typography.bodyLarge)
                    .preferredColorScheme(.light)
            } else {
                StaffLoginView()
                    .environmentObject(appState)
                    .tint(.chettinadPrimary)
                    .font(Typography.bodyLarge)
                    .preferredColorScheme(.light)
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
            await SessionManager.shared.logout(apiClient: APIClient())
            self.isAuthenticated = false
            self.role = ""
        }
    }
}
