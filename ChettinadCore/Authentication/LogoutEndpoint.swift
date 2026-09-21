import Foundation

public struct LogoutEndpoint: APIEndpoint {
    public var path: String { "/api/v1/auth/logout" }
    public var method: HTTPMethod { .post }
    public var headers: [String: String]? { nil }
    public var queryItems: [URLQueryItem]? { nil }
    public var body: Data? { nil }
    
    public init() {}
}
