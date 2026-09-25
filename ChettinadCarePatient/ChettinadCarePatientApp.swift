import SwiftUI
import ChettinadCore

@main
struct ChettinadCarePatientApp: App {
    @StateObject private var appState = AppState()
    
    init() { StitchTheme.registerFonts() }

    var body: some Scene {
        WindowGroup {
            if appState.isAuthenticated {
                MainTabView()
                    .environmentObject(appState)
                    .tint(.chettinadPrimary)
                    .font(Typography.bodyLarge)
                    .preferredColorScheme(.light)
            } else {
                LoginView()
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
    
    init() {
        checkSession()
    }
    
    func checkSession() {
        Task {
            if let session = await SessionManager.shared.getSession(), session.role.uppercased() == "PATIENT" {
                self.isAuthenticated = true
            } else {
                self.isAuthenticated = false
            }
        }
    }
    
    func logout() {
        Task {
            await SessionManager.shared.logout(apiClient: APIClient())
            self.isAuthenticated = false
        }
    }
}
