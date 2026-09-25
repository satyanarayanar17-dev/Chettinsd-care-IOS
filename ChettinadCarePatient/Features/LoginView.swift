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
        StitchLoginShell(title: isProfileRequired ? "Patient Registration" : "Patient Sign In", subtitle: "Sign in to view test results, consult records & prescriptions.") {
            Label("Sign in with OTP", systemImage: "message").font(Typography.titleMedium).foregroundStyle(Color.chettinadPrimary)
            Text("REGISTERED MOBILE NUMBER").font(Typography.labelMedium).tracking(1.5).padding(.top, 12)
            TextField("Mobile Number", text: $phone).keyboardType(.phonePad).stitchField().disabled(isCodeSent)
            if isCodeSent {
                Text("6-DIGIT ACCESS CODE / OTP").font(Typography.labelMedium).tracking(1.5)
                TextField("OTP Code", text: $code).keyboardType(.numberPad).textContentType(.oneTimeCode).stitchField()
            }
            if isProfileRequired {
                TextField("Full Name", text: $profileName).stitchField()
                DatePicker("Date of Birth", selection: $dob, displayedComponents: .date)
                Picker("Gender", selection: $gender) { ForEach(genders, id: \.self) { Text($0) } }
                TextField("Address", text: $address).stitchField()
                TextField("City", text: $city).stitchField()
                TextField("State", text: $state).stitchField()
                TextField("PIN Code", text: $pinCode).keyboardType(.numberPad).stitchField()
                TextField("Emergency Contact", text: $emergencyContact).keyboardType(.phonePad).stitchField()
            }
            if let error = errorMessage { Text(error).font(Typography.bodySmall).foregroundStyle(Color.chettinadError) }
            Button(action: { isCodeSent ? verifyOTP() : requestOTP() }) {
                HStack { Text(isLoading ? "Please wait…" : (isCodeSent ? "ACCESS HEALTH RECORDS" : "SEND VERIFICATION CODE")); Image(systemName: "arrow.right") }
            }.buttonStyle(StitchButtonStyle()).disabled(isLoading || phone.isEmpty || (isCodeSent && code.isEmpty)).padding(.top, 12)
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
                    #if DEBUG
                    if let devCode = response.development_code {
                        print("Dev OTP Code: \(devCode)")
                        self.code = devCode // auto-fill for convenience (Debug builds only)
                    }
                    #endif
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
                
                try await SessionManager.shared.saveSession(session)
                
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
