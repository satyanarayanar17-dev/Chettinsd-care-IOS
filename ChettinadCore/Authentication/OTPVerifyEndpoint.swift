import Foundation

public struct OTPVerifyEndpoint: APIEndpoint {
    public var path: String { "/api/v1/auth/opd/otp/verify" }
    public var method: HTTPMethod { .post }
    public var body: Data? {
        var payload: [String: String] = [
            "phone": phone,
            "code": code
        ]
        
        if let name = profileName {
            // Note: If profile is required (isNewPatient), we can pass a nested profile object
            // Just sending name in profile as a workaround. Real object depends on schema.
            // Wait, schema requires "profile" object if patient doesn't exist.
            // Actually I should make a struct for it.
        }
        
        return try? JSONEncoder().encode(OTPVerifyPayload(phone: phone, code: code, profile: profileName != nil ? OTPProfile(name: profileName!) : nil))
    }
    
    private let phone: String
    private let code: String
    private let profileName: String?
    
    public init(phone: String, code: String, profileName: String? = nil) {
        self.phone = phone
        self.code = code
        self.profileName = profileName
    }
}

private struct OTPVerifyPayload: Codable {
    let phone: String
    let code: String
    let profile: OTPProfile?
}

private struct OTPProfile: Codable {
    let name: String
}

public struct OTPVerifyResponse: Codable {
    public let access_token: String
    public let role: String
    public let account_type: String
    public let userId: String
    public let name: String?
    public let must_change_password: Bool
}
