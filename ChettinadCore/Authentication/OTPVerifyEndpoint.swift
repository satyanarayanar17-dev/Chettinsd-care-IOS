import Foundation

public struct PatientProfilePayload: Codable, Sendable {
    public let name: String
    public let dob: String
    public let gender: String
    public let address: String
    public let city: String
    public let state: String
    public let pin_code: String
    public let emergency_contact: String
    public let preferred_language: String
    
    public init(name: String, dob: String, gender: String, address: String, city: String, state: String, pin_code: String, emergency_contact: String, preferred_language: String) {
        self.name = name
        self.dob = dob
        self.gender = gender
        self.address = address
        self.city = city
        self.state = state
        self.pin_code = pin_code
        self.emergency_contact = emergency_contact
        self.preferred_language = preferred_language
    }
}

public struct OTPVerifyEndpoint: APIEndpoint {
    public var path: String { "/api/v1/auth/opd/otp/verify" }
    public var method: HTTPMethod { .post }
    public var body: Data? {
        return try? JSONEncoder().encode(OTPVerifyPayload(
            phone: phone,
            code: code,
            profile: profile,
            challenge_id: challengeId,
            purpose: "PATIENT_LOGIN"
        ))
    }
    
    private let phone: String
    private let code: String
    private let profile: PatientProfilePayload?
    private let challengeId: String?
    
    public init(phone: String, code: String, profile: PatientProfilePayload? = nil, challengeId: String? = nil) {
        self.phone = phone
        self.code = code
        self.profile = profile
        self.challengeId = challengeId
    }
}

private struct OTPVerifyPayload: Codable {
    let phone: String
    let code: String
    let profile: PatientProfilePayload?
    let challenge_id: String?
    let purpose: String
}

public struct OTPVerifyResponse: Codable {
    public let access_token: String
    public let role: String
    public let account_type: String
    public let userId: String
    public let name: String?
    @FlexibleBool public var must_change_password: Bool
}
