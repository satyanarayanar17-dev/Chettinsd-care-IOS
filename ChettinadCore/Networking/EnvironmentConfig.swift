import Foundation

public enum AppEnvironment: String, Sendable {
    case local = "local"
    case staging = "staging"
    case production = "production"
    
    public var baseURL: URL {
        let configured = Bundle.main.object(forInfoDictionaryKey: "CC_API_BASE_URL") as? String
        do { return try EnvironmentConfig.resolveAPIBaseURL(environment: self, configuredValue: configured) }
        catch { preconditionFailure("Configure a valid HTTPS CC_API_BASE_URL for this app environment.") }
    }
}

public struct EnvironmentConfig {
    public static var current: AppEnvironment {
        if let value = Bundle.main.object(forInfoDictionaryKey: "APP_ENV") as? String,
           let environment = AppEnvironment(rawValue: value) { return environment }
        #if DEBUG
        return .local
        #else
        return .production
        #endif
    }
    public enum ConfigurationError: Error { case invalidAPIURL }
    public static func resolveAPIBaseURL(environment: AppEnvironment, configuredValue: String?) throws -> URL {
        let fallback: String
        switch environment {
        case .local: fallback = "https://chettinad-care-api.onrender.com"
        case .staging: fallback = "https://staging-api.chettinad.care"
        case .production: fallback = "https://api.chettinad.care"
        }
        let value = configuredValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var parts = URLComponents(string: value?.isEmpty == false ? value! : fallback),
              let host = parts.host, parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
              parts.scheme == "https" || (environment == .local && parts.scheme == "http" && ["127.0.0.1", "localhost", "::1"].contains(host))
        else { throw ConfigurationError.invalidAPIURL }
        if parts.path == "/api/v1" || parts.path == "/api/v1/" { parts.path = "" }
        guard let url = parts.url else { throw ConfigurationError.invalidAPIURL }
        return url
    }
}
