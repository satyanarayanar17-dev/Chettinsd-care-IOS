import SwiftUI
import UserNotifications
import ChettinadCore

@main
struct ChettinadCarePatientApp: App {
    @AppStorage("interface-language") private var language = "en"
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
                    MainTabView()
                } else {
                    LoginView()
                }
            }
            .safeAreaInset(edge:.top) { if EnvironmentConfig.current == .local { DemoEnvironmentBanner() } }
            .environmentObject(appState)
            .environment(\.locale,Locale(identifier:language))
            .environment(\.timeZone,TimeZone(identifier:"Asia/Kolkata")!)
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
    /// False until the stored session has been checked, so the login screen doesn't flash at launch.
    @Published var hasCheckedSession = false
    
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
        // Care plan reminders belong to the signed-in patient; don't leave them behind.
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        isAuthenticated = false
    }
}
