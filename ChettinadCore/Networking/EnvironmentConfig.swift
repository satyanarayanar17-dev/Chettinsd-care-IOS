import Foundation

public enum AppEnvironment: String, Sendable {
    case local = "local"
    case staging = "staging"
    case production = "production"
    
    public var baseURL: URL {
        let configured = Bundle.main.object(forInfoDictionaryKey: "CC_API_BASE_URL") as? String
        if let url = EnvironmentConfig.resolveBaseURL(configured, environment: self) { return url }
        preconditionFailure("The app must be built with a valid CC_API_BASE_URL for its environment.")
    }
}

public struct EnvironmentConfig {
    public static var current: AppEnvironment {
        AppEnvironment(rawValue: Bundle.main.object(forInfoDictionaryKey: "APP_ENV") as? String ?? "local") ?? .production
    }

    public static func resolveBaseURL(_ configured: String?, environment: AppEnvironment) -> URL? {
        let value = configured?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if value.isEmpty { return environment == .local ? URL(string: "http://127.0.0.1:3001") : nil }
        guard let url = URL(string: value), let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              url.path.isEmpty || url.path == "/" else { return nil }
        let local = ["localhost", "127.0.0.1", "::1"].contains(host)
        guard url.scheme == "https" || (environment == .local && local && url.scheme == "http") else { return nil }
        return url
    }
}
