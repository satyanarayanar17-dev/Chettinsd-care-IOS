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
            Text("STAFF ID").font(Typography.labelMedium).tracking(2)
            TextField("Username (Staff ID)", text: $username)
                .textInputAutocapitalization(.never).autocorrectionDisabled().stitchField()
            Text("PASSWORD").font(Typography.labelMedium).tracking(2).padding(.top, 8)
            SecureField("Password", text: $password).stitchField()
            if let error = errorMessage { Text(error).font(Typography.bodySmall).foregroundStyle(Color.chettinadError) }
            Button(action: login) {
                HStack { Text(isLoading ? "Signing in…" : "ACCESS CLINICAL WORKSPACE"); Image(systemName: "arrow.right") }
            }.buttonStyle(StitchButtonStyle()).disabled(isLoading || username.isEmpty || password.isEmpty).padding(.top, 12)
        }
    }

    func login() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let response: LoginResponse = try await apiClient.execute(endpoint: StaffLoginEndpoint(username: username, password: password))
                
                if response.role.uppercased() == "PATIENT" {
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
