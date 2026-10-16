import SwiftUI
import ChettinadCore

@MainActor
final class PatientLoginViewModel: ObservableObject {
    @Published var phone = ""
    @Published var code = ""
    @Published private(set) var challengeId: String?
    @Published private(set) var expiresAt: Date?
    @Published private(set) var resendAt: Date?
    @Published private(set) var isProfileRequired = false
    @Published private(set) var isLoading = false
    @Published private(set) var demoCode: String?
    @Published var errorMessage: String?
    private let client: APIClient
    private let now: () -> Date
    init(client: APIClient = APIClient(), now: @escaping () -> Date = Date.init) { self.client = client; self.now = now }
    var isCodeSent: Bool { challengeId != nil }
    var normalizedPhone: String { phone.filter(\.isNumber) }
    var canRequest: Bool { !isLoading && normalizedPhone.count == 10 && (resendAt ?? .distantPast) <= now() }
    var canVerify: Bool { !isLoading && isCodeSent && code.count == 6 && code.allSatisfy(\.isNumber) && (expiresAt ?? .distantPast) > now() }

    func changePhone() {
        guard !isLoading else { return }
        challengeId = nil; code = ""; demoCode = nil; expiresAt = nil; resendAt = nil; isProfileRequired = false; errorMessage = nil
    }
    func requestCode() async {
        guard canRequest else { return }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let response: OTPRequestResponse = try await client.execute(endpoint: OTPRequestEndpoint(phone: normalizedPhone))
            guard response.sent, let id = response.challenge_id, !id.isEmpty,
                  let expiry = response.expires_in, expiry > 0 else { throw APIError.invalidResponse }
            challengeId = id; code = ""; isProfileRequired = false
            expiresAt = now().addingTimeInterval(TimeInterval(expiry))
            resendAt = now().addingTimeInterval(TimeInterval(max(0, response.retry_after ?? 60)))
            #if DEBUG
            demoCode = EnvironmentConfig.current == .local ? response.development_code : nil
            #endif
        } catch { errorMessage = error.localizedDescription }
    }
    func verify(profile: PatientProfilePayload? = nil) async -> AuthSession? {
        guard canVerify, let challengeId else {
            errorMessage = "Request a new code if the current one has expired."
            return nil
        }
        isLoading = true; errorMessage = nil
        defer { isLoading = false }
        do {
            let response: OTPVerifyResponse = try await client.execute(endpoint: OTPVerifyEndpoint(phone: normalizedPhone, code: code, profile: profile, challengeId: challengeId))
            guard response.role.uppercased() == "PATIENT", response.account_type.uppercased() == "PATIENT" else {
                throw APIError.unauthenticated
            }
            return AuthSession(accessToken: response.access_token, role: "PATIENT", accountType: "PATIENT", userId: response.userId, name: response.name)
        } catch let error as APIError {
            if case .apiError(_, let response) = error, response.error.code == "PROFILE_REQUIRED" {
                isProfileRequired = true; errorMessage = "Complete your details to create your patient record."
            } else { errorMessage = error.localizedDescription }
            return nil
        } catch { errorMessage = error.localizedDescription; return nil }
    }
}

struct LoginView: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("interface-language") private var interfaceLanguage = "en"
    @StateObject private var model = PatientLoginViewModel()
    @State private var profileName = ""
    @State private var dob = Date()
    @State private var dobConfirmed = false
    @State private var gender = "Not specified"
    @State private var address = ""
    @State private var city = ""
    @State private var state = ""
    @State private var pinCode = ""
    @State private var emergencyContact = ""
    private let genders = ["Female", "Male", "Other", "Not specified"]
    var body: some View {
        StitchLoginShell(title: model.isProfileRequired ? "Patient Registration" : "Patient Sign In", subtitle: "Sign in to view test results, visit records and prescriptions.") {
            InterfaceLanguagePicker()
            TextField("10-digit mobile number", text: $model.phone).keyboardType(.phonePad).textContentType(.telephoneNumber).stitchField().disabled(model.isCodeSent || model.isLoading).accessibilityIdentifier("patient.phone")
            if model.isCodeSent {
                if let demoCode = model.demoCode { Text("Synthetic demo code: \(demoCode)").font(.caption).accessibilityIdentifier("patient.demo.code") }
                Text("Code sent to \(model.normalizedPhone)").font(.caption)
                TextField("6-digit verification code", text: $model.code).keyboardType(.numberPad).textContentType(.oneTimeCode).stitchField().accessibilityIdentifier("patient.otp")
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let expiry = max(0, Int((model.expiresAt ?? .distantPast).timeIntervalSince(context.date)))
                    let retry = max(0, Int(ceil((model.resendAt ?? .distantPast).timeIntervalSince(context.date))))
                    VStack(alignment: .leading) {
                        Text(expiry > 0 ? "Code expires in \(expiry / 60)m \(expiry % 60)s" : "Code expired. Request a new code.").font(.caption)
                        Button(retry > 0 ? "Resend in \(retry)s" : "Resend code") { Task { await model.requestCode() } }.disabled(retry > 0 || model.isLoading)
                    }
                }
                Button("Change mobile number") { model.changePhone() }.disabled(model.isLoading)
            }
            if model.isProfileRequired {
                TextField("Full name", text: $profileName).textContentType(.name).stitchField()
                DatePicker("Date of birth", selection: $dob, in: ...Date(), displayedComponents: .date).onChange(of: dob) { _ in dobConfirmed = true }
                Toggle("I confirm this date of birth", isOn: $dobConfirmed)
                Picker("Gender", selection: $gender) { ForEach(genders, id: \.self) { Text($0) } }
                TextField("Address", text: $address).stitchField()
                TextField("City", text: $city).stitchField()
                TextField("State", text: $state).stitchField()
                TextField("PIN code", text: $pinCode).keyboardType(.numberPad).stitchField()
                TextField("Emergency contact", text: $emergencyContact).keyboardType(.phonePad).stitchField()
            }
            if let error = model.errorMessage { Text(error).font(Typography.bodySmall).foregroundStyle(Color.chettinadError).accessibilityLabel("Sign in error: \(error)") }
            Button(model.isLoading ? "Please wait…" : (model.isCodeSent ? "Continue" : "Send verification code")) {
                Task {
                    if model.isCodeSent {
                        guard let session = await model.verify(profile: profilePayload) else { return }
                        do { try await SessionManager.shared.saveSession(session); appState.isAuthenticated = true }
                        catch { model.errorMessage = error.localizedDescription }
                    } else { await model.requestCode() }
                }
            }.buttonStyle(StitchButtonStyle()).disabled(model.isLoading || (model.isCodeSent ? !model.canVerify || (model.isProfileRequired && (!dobConfirmed || profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)) : !model.canRequest)).accessibilityIdentifier("patient.login.continue")
        }
    }
    private var profilePayload: PatientProfilePayload? {
        guard model.isProfileRequired else { return nil }
        let df = DateFormatter(); df.calendar = Calendar(identifier: .gregorian); df.locale = Locale(identifier: "en_US_POSIX"); df.timeZone = TimeZone(identifier:"Asia/Kolkata"); df.dateFormat = "yyyy-MM-dd"
        return PatientProfilePayload(name: profileName.trimmingCharacters(in: .whitespacesAndNewlines), dob: df.string(from: dob), gender: gender, address: address, city: city, state: state, pin_code: pinCode, emergency_contact: emergencyContact, preferred_language: interfaceLanguage)
    }
}
