import Foundation

public enum AppEnvironment: String, Sendable {
    case local = "local"
    case staging = "staging"
    case production = "production"
    
    public var baseURL: URL {
        // HARDCODED TO CLOUD FOR PILOT TESTING
        return URL(string: "https://chettinad-care-api.onrender.com")!
    }
}

public struct EnvironmentConfig {
    public static let current: AppEnvironment = .production
}
