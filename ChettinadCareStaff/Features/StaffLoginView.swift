import SwiftUI
import ChettinadCore

struct StaffLoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var username = ""
    @State private var password = ""
    @State private var errorMessage: String? = nil
    @State private var isLoading = false
    
    let apiClient = APIClient()
    
    var body: some View {
        StitchLoginShell(title: "Staff Sign In", subtitle: "Clinical care. Connected. Sign in to your hospital workspace.") {
            InterfaceLanguagePicker()
            Text("STAFF ID").font(Typography.labelMedium).tracking(2)
            TextField("Username (Staff ID)", text: $username)
                .textInputAutocapitalization(.never).autocorrectionDisabled().stitchField().accessibilityIdentifier("staff.username")
            Text("PASSWORD").font(Typography.labelMedium).tracking(2).padding(.top, 8)
            SecureField("Password", text: $password).stitchField().accessibilityIdentifier("staff.password")
            if let error = errorMessage { Text(error).font(Typography.bodySmall).foregroundStyle(Color.chettinadError) }
            Button(action: login) {
                HStack { Text(isLoading ? "Signing in…" : "ACCESS CLINICAL WORKSPACE"); Image(systemName: "arrow.right") }
            }.buttonStyle(StitchButtonStyle()).accessibilityIdentifier("staff.login").disabled(isLoading || username.isEmpty || password.isEmpty).padding(.top, 12)
        }
    }

    func login() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let response: LoginResponse = try await apiClient.execute(endpoint: StaffLoginEndpoint(username: username, password: password))
                
                if !["ADMIN", "DOCTOR", "NURSE"].contains(response.role.uppercased()) || response.account_type.uppercased() != "STAFF" {
                    throw NSError(domain: "", code: 403, userInfo: [NSLocalizedDescriptionKey: "Patients cannot sign in here."])
                }
                
                let session = AuthSession(
                    accessToken: response.access_token,
                    role: response.role.uppercased(),
                    accountType: response.account_type.uppercased(),
                    userId: response.userId,
                    name: response.name
                )
                
                try await SessionManager.shared.saveSession(session)
                
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.appState.mustChangePassword = response.must_change_password
                    self.appState.role = response.role.uppercased()
                    self.appState.isAuthenticated = true
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Login failed: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}

struct StaffPasswordChangeEndpoint: APIEndpoint {
    let currentPassword: String
    let newPassword: String
    var path: String { "/api/v1/auth/change-password" }
    var method: HTTPMethod { .post }
    var body: Data? {
        struct Payload: Encodable { let currentPassword: String; let newPassword: String }
        return try? JSONEncoder().encode(Payload(currentPassword: currentPassword, newPassword: newPassword))
    }
}

struct StaffPasswordRules {
    static func accepts(_ password: String) -> Bool {
        (12...72).contains(password.count) && ["[a-z]", "[A-Z]", "[0-9]", "[^a-zA-Z0-9]"].allSatisfy {
            password.range(of: $0, options: .regularExpression) != nil
        }
    }
}

struct StaffPasswordChangeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmation = ""
    @State private var saving = false
    @State private var errorMessage: String?

    var body: some View {
        StitchLoginShell(title: "Set your password", subtitle: "Replace your initial password before entering the staff workspace.") {
            SecureField("Current password", text: $currentPassword).textContentType(.password).stitchField()
            SecureField("New password", text: $newPassword).textContentType(.newPassword).stitchField()
            SecureField("Confirm new password", text: $confirmation).textContentType(.newPassword).stitchField()
            Text("Use 12–72 characters with an uppercase letter, a lowercase letter, a number, and a symbol.")
                .font(Typography.bodySmall).foregroundStyle(Color.chettinadTextSecondary)
            if let errorMessage { StitchErrorState(message: errorMessage) }
            Button(saving ? "Updating…" : "Update password") {
                saving = true
                errorMessage = nil
                Task {
                    do {
                        let _: EmptyResponse = try await APIClient().execute(endpoint: StaffPasswordChangeEndpoint(currentPassword: currentPassword, newPassword: newPassword))
                        currentPassword = ""
                        newPassword = ""
                        confirmation = ""
                        appState.mustChangePassword = false
                    } catch { errorMessage = error.localizedDescription }
                    saving = false
                }
            }
            .buttonStyle(StitchPrimaryButtonStyle())
            .disabled(saving || currentPassword.isEmpty || newPassword == currentPassword || !StaffPasswordRules.accepts(newPassword) || confirmation != newPassword)
            Button("Sign Out", role: .destructive) { appState.logout() }.disabled(saving)
        }
    }
}
