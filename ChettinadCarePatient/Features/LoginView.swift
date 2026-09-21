import SwiftUI
import ChettinadCore

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @State private var phone: String = ""
    @State private var code: String = ""
    @State private var isCodeSent: Bool = false
    
    // Profile Fields
    @State private var isProfileRequired: Bool = false
    @State private var profileName: String = ""
    @State private var dob: Date = Calendar.current.date(byAdding: .year, value: -30, to: Date()) ?? Date()
    @State private var gender: String = "Not specified"
    @State private var address: String = ""
    @State private var city: String = ""
    @State private var state: String = ""
    @State private var pinCode: String = ""
    @State private var emergencyContact: String = ""
    
    @State private var errorMessage: String? = nil
    @State private var isLoading: Bool = false
    
    let apiClient = APIClient()
    
    let genders = ["Female", "Male", "Other", "Not specified"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Authentication")) {
                    if !isCodeSent {
                        TextField("Mobile Number", text: $phone)
                            .keyboardType(.phonePad)
                        
                        Button("Request OTP") {
                            requestOTP()
                        }
                        .disabled(isLoading || phone.isEmpty)
                    } else {
                        TextField("OTP Code", text: $code)
                            .keyboardType(.numberPad)
                        
                        if !isProfileRequired {
                            Button("Verify OTP") {
                                verifyOTP()
                            }
                            .disabled(isLoading || code.isEmpty)
                        }
                    }
                }
                
                if isProfileRequired {
                    Section(header: Text("Patient Registration")) {
                        TextField("Full Name", text: $profileName)
                        DatePicker("Date of Birth", selection: $dob, displayedComponents: .date)
                        Picker("Gender", selection: $gender) {
                            ForEach(genders, id: \.self) { g in
                                Text(g).tag(g)
                            }
                        }
                        TextField("Address", text: $address)
                        TextField("City", text: $city)
                        TextField("State", text: $state)
                        TextField("PIN Code", text: $pinCode)
                            .keyboardType(.numberPad)
                        TextField("Emergency Contact", text: $emergencyContact)
                            .keyboardType(.phonePad)
                        
                        Button("Complete Registration & Verify") {
                            verifyOTP()
                        }
                        .disabled(isLoading || profileName.isEmpty || address.isEmpty || city.isEmpty || state.isEmpty || pinCode.isEmpty || emergencyContact.isEmpty)
                    }
                }
                
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(isProfileRequired ? "Register" : "Sign In")
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
                    if let devCode = response.development_code {
                        print("Dev OTP Code: \(devCode)")
                        self.code = devCode // auto-fill for convenience
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
                var profile: PatientProfilePayload? = nil
                if isProfileRequired {
                    let df = DateFormatter()
                    df.dateFormat = "yyyy-MM-dd"
                    profile = PatientProfilePayload(
                        name: profileName,
                        dob: df.string(from: dob),
                        gender: gender,
                        address: address,
                        city: city,
                        state: state,
                        pin_code: pinCode,
                        emergency_contact: emergencyContact,
                        preferred_language: "en"
                    )
                }
                
                let response: OTPVerifyResponse = try await apiClient.execute(endpoint: OTPVerifyEndpoint(phone: phone, code: code, profile: profile))
                
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
            } catch let error as APIError {
                DispatchQueue.main.async {
                    if case .apiError(_, let apiError) = error, apiError.error.code == "PROFILE_REQUIRED" {
                        self.isProfileRequired = true
                        self.errorMessage = "Profile required for new patient."
                    } else {
                        self.errorMessage = "Failed to verify OTP: \(error.localizedDescription)"
                    }
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
