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
        NavigationStack {
            VStack(spacing: 20) {
                Text("Chettinad Care")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Staff Portal")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                TextField("Username (Staff ID)", text: $username)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .padding(.horizontal)
                
                SecureField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal)
                
                Button("Sign In") {
                    login()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading || username.isEmpty || password.isEmpty)
            }
            .padding()
            .navigationTitle("Sign In")
            .navigationBarHidden(true)
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
                
                await SessionManager.shared.saveSession(session)
                
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
