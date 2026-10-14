import SwiftUI
import ChettinadCore

@main
struct ChettinadCareStaffApp: App {
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
                } else if let error = appState.sessionValidationError {
                    VStack(spacing: StitchSpacing.lg) {
                        StitchErrorState(message: error) { appState.checkSession() }
                        Button("Sign Out", role: .destructive) { appState.logout() }
                    }.padding(StitchSpacing.lg)
                } else if appState.isAuthenticated {
                    if appState.mustChangePassword { StaffPasswordChangeView() }
                    else { StaffMainView() }
                } else {
                    StaffLoginView()
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
    @Published var role: String = ""
    @Published var mustChangePassword = false
    @Published var sessionValidationError: String?
    /// False until the stored session has been checked, so the login screen doesn't flash at launch.
    @Published var hasCheckedSession = false
    
    init() {
        checkSession()
    }
    
    func checkSession() {
        hasCheckedSession = false
        sessionValidationError = nil
        Task {
            defer { hasCheckedSession = true }
            guard let session = await SessionManager.shared.getSession(),
                  ["ADMIN", "DOCTOR", "NURSE"].contains(session.role.uppercased()),
                  session.accountType.uppercased() == "STAFF" else {
                isAuthenticated = false
                return
            }
            do {
                let verified: UserSession = try await APIClient().execute(endpoint: OPDSessionEndpoint())
                guard ["ADMIN", "DOCTOR", "NURSE"].contains(verified.role.uppercased()) else {
                    await SessionManager.shared.clearSession()
                    handleSessionEnded()
                    return
                }
                isAuthenticated = true
                role = verified.role.uppercased()
                mustChangePassword = verified.must_change_password
            } catch {
                if await SessionManager.shared.getSession() != nil {
                    sessionValidationError = "We couldn't verify your staff session. Check your connection and retry."
                } else { handleSessionEnded() }
            }
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
        mustChangePassword = false
        sessionValidationError = nil
    }
}
