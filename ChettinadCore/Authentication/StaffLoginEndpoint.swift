import Foundation

public struct StaffLoginEndpoint: APIEndpoint {
    public var path: String { "/api/v1/auth/login/staff" }
    public var method: HTTPMethod { .post }
    public var body: Data? {
        let payload = [
            "username": username,
            "password": password
        ]
        return try? JSONEncoder().encode(payload)
    }
    
    private let username: String
    private let password: String
    
    public init(username: String, password: String) {
        self.username = username
        self.password = password
    }
}

public struct LoginResponse: Codable {
    public let access_token: String
    public let role: String
    public let account_type: String
    public let userId: String
    public let name: String?
    @FlexibleBool public var must_change_password: Bool
}
