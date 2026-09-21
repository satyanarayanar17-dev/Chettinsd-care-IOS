import Foundation

public enum AppEnvironment: String, Sendable {
    case local = "local"
    case staging = "staging"
    case production = "production"
    
    public var baseURL: URL {
        switch self {
        case .local:
            return URL(string: "http://127.0.0.1:3001")!
        case .staging:
            return URL(string: "https://staging-api.chettinad.care")!
        case .production:
            return URL(string: "https://api.chettinad.care")!
        }
    }
}

public struct EnvironmentConfig {
    public static let current: AppEnvironment = {
        // Read from Info.plist or env vars
        if let envString = Bundle.main.object(forInfoDictionaryKey: "APP_ENV") as? String,
           let env = AppEnvironment(rawValue: envString) {
            return env
        }
        #if targetEnvironment(simulator)
        return .local
        #else
        return .staging // Default to staging on device if not specified
        #endif
    }()
}
