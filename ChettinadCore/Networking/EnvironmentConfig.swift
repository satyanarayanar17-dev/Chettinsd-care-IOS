import Foundation

public enum AppEnvironment: String, Sendable {
    case local = "local"
    case staging = "staging"
    case production = "production"
    
    public var baseURL: URL {
        if let configured = Bundle.main.object(forInfoDictionaryKey: "CC_API_BASE_URL") as? String,
           !configured.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let url = URL(string: configured) {
            return url
        }
        switch self {
        case .local:
            #if DEBUG
            if let override = ProcessInfo.processInfo.environment["CC_API_BASE_URL"],
               let url = URL(string: override) {
                return url
            }
            #endif
            #if targetEnvironment(simulator)
            return URL(string: "http://127.0.0.1:3001")!
            #else
            return URL(string: "http://Sids-MacBook-Pro.local:3001")!
            #endif
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
        #if DEBUG
        return .local // Always use local during debugging, even on physical device
        #else
        return .staging
        #endif
    }()
}
