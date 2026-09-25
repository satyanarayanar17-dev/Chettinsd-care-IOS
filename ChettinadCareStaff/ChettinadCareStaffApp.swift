import SwiftUI
import ChettinadCore

@main
struct ChettinadCareStaffApp: App {
    @StateObject private var appState = AppState()
    
    init() { StitchTheme.registerFonts() }

    var body: some Scene {
        WindowGroup {
            Group {
                if !appState.hasCheckedSession {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.chettinadBackground)
                } else if appState.isAuthenticated {
                    StaffMainView()
                } else {
                    StaffLoginView()
                }
            }
            .environmentObject(appState)
            .tint(.chettinadPrimary)
            .font(Typography.bodyLarge)
            .preferredColorScheme(.light)
            .onReceive(NotificationCenter.default.publisher(for: .chettinadSessionEnded)) { _ in
                appState.handleSessionEnded()
            }
        }
    }
}

@MainActor
class AppState: ObservableObject {
    @Published var isAuthenticated = false
    @Published var role: String = ""
    /// False until the stored session has been checked, so the login screen doesn't flash at launch.
    @Published var hasCheckedSession = false
    
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
            self.hasCheckedSession = true
        }
    }
    
    func logout() {
        Task {
            await SessionManager.shared.logout(apiClient: APIClient())
            self.handleSessionEnded()
        }
    }

    /// Called on explicit logout and whenever the session is cleared (e.g. the refresh token was rejected).
    func handleSessionEnded() {
        isAuthenticated = false
        role = ""
    }
}
