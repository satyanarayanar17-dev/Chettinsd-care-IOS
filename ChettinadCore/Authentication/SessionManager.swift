import Foundation

public struct AuthSession: Codable, Sendable {
    public let accessToken: String
    public let role: String
    public let accountType: String
    public let userId: String
    public let name: String?
    
    public init(accessToken: String, role: String, accountType: String, userId: String, name: String?) {
        self.accessToken = accessToken
        self.role = role
        self.accountType = accountType
        self.userId = userId
        self.name = name
    }
}

public actor SessionManager {
    public static let shared = SessionManager()
    
    private let service = "com.chettinadcare.auth"
    private let account = "session"
    
    private var currentSession: AuthSession?
    private var refreshTask: Task<AuthSession, Error>?
    
    public init() {
        if let data = KeychainHelper.shared.read(service: service, account: account),
           let session = try? JSONDecoder().decode(AuthSession.self, from: data) {
            self.currentSession = session
        }
    }
    
    public func saveSession(_ session: AuthSession) {
        self.currentSession = session
        if let data = try? JSONEncoder().encode(session) {
            KeychainHelper.shared.save(data, service: service, account: account)
        }
    }
    
    public func logout(apiClient: APIClient) async {
        do {
            let endpoint = LogoutEndpoint()
            let _: [String: String]? = try? await apiClient.executeRaw(endpoint: endpoint)
        }
        clearSession()
    }
    
    public func clearSession() {
        self.currentSession = nil
        KeychainHelper.shared.delete(service: service, account: account)
        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
    }
    
    public func getSession() -> AuthSession? {
        return currentSession
    }
    
    public func getAccessToken() -> String? {
        return currentSession?.accessToken
    }
    
    /// Executes a refresh with single-flight prevention.
    public func refreshToken(apiClient: APIClient) async throws -> AuthSession {
        if let refreshTask = refreshTask {
            return try await refreshTask.value
        }
        
        let task = Task { () -> AuthSession in
            defer { self.refreshTask = nil }
            do {
                let response: RefreshResponse = try await apiClient.executeRaw(
                    endpoint: RefreshEndpoint()
                )
                
                guard let current = self.currentSession else {
                    throw APIError.unauthenticated
                }
                
                let newSession = AuthSession(
                    accessToken: response.access_token,
                    role: response.role,
                    accountType: response.account_type,
                    userId: current.userId,
                    name: current.name
                )
                self.saveSession(newSession)
                return newSession
            } catch {
                self.clearSession()
                throw error
            }
        }
        
        self.refreshTask = task
        return try await task.value
    }
}

struct RefreshEndpoint: APIEndpoint {
    var path: String { "/api/v1/auth/refresh" }
    var method: HTTPMethod { .post }
}

struct RefreshResponse: Codable {
    let access_token: String
    let role: String
    let account_type: String
}
