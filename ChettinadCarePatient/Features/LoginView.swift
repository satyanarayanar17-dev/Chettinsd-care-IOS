import SwiftUI
import ChettinadCore

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var phone: String = ""
    @State private var code: String = ""
    @State private var isCodeSent: Bool = false
    @State private var profileName: String = ""
    @State private var isProfileRequired: Bool = false
    @State private var errorMessage: String? = nil
    @State private var isLoading: Bool = false
    
    let apiClient = APIClient()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Chettinad Care")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Patient Portal")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                if !isCodeSent {
                    TextField("Mobile Number", text: $phone)
                        .keyboardType(.phonePad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    Button("Request OTP") {
                        requestOTP()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || phone.isEmpty)
                } else {
                    TextField("OTP Code", text: $code)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                    
                    if isProfileRequired {
                        TextField("Full Name (New Patient)", text: $profileName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)
                    }
                    
                    Button("Verify OTP") {
                        verifyOTP()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || code.isEmpty)
                }
            }
            .padding()
            .navigationTitle("Sign In")
            .navigationBarHidden(true)
        }
    }
    
    func requestOTP() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let response: OTPRequestResponse = try await apiClient.execute(endpoint: OTPRequestEndpoint(phone: phone))
                DispatchQueue.main.async {
                    self.isCodeSent = response.sent
                    self.isLoading = false
                    // For dev/testing if development_code is returned
                    if let devCode = response.development_code {
                        print("Dev OTP Code: \(devCode)")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to request OTP: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    func verifyOTP() {
        isLoading = true
        errorMessage = nil
        Task {
            do {
                let nameToPass = isProfileRequired ? profileName : nil
                let response: OTPVerifyResponse = try await apiClient.execute(endpoint: OTPVerifyEndpoint(phone: phone, code: code, profileName: nameToPass))
                
                if response.role.uppercased() != "PATIENT" {
                    throw NSError(domain: "", code: 403, userInfo: [NSLocalizedDescriptionKey: "Only patients can sign in here."])
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
                    self.appState.isAuthenticated = true
                }
            } catch APIError.apiError(let apiError) where apiError.error.code == "PROFILE_REQUIRED" {
                DispatchQueue.main.async {
                    self.isProfileRequired = true
                    self.errorMessage = "Profile required for new patient."
                    self.isLoading = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to verify OTP: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
}
