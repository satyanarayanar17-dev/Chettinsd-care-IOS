import Foundation

public struct OTPRequestEndpoint: APIEndpoint {
    public var path: String { "/api/v1/auth/opd/otp/request" }
    public var method: HTTPMethod { .post }
    public var body: Data? {
        let payload = ["phone": phone,"purpose":"PATIENT_LOGIN"]
        return try? JSONEncoder().encode(payload)
    }
    
    private let phone: String
    
    public init(phone: String) {
        self.phone = phone
    }
}

public struct OTPRequestResponse: Codable, Sendable {
    public let sent: Bool
    public let expires_in: Int?
    public let development_code: String?
    public let challenge_id: String?
    public let retry_after: Int?
}
