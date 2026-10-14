import Foundation

public extension Notification.Name {
    /// Posted on the main actor whenever the stored session is cleared (logout or rejected refresh).
    static let chettinadSessionEnded = Notification.Name("ChettinadSessionEnded")
}

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

public protocol AuthSessionStorage: Sendable {
    func read() -> Data?
    func save(_ data: Data) -> Bool
    func delete()
}
public struct KeychainSessionStorage: AuthSessionStorage {
    public init() {}
    public func read() -> Data? { KeychainHelper.shared.read(service: "com.chettinadcare.auth", account: "session") }
    public func save(_ data: Data) -> Bool { KeychainHelper.shared.save(data, service: "com.chettinadcare.auth", account: "session") }
    public func delete() { KeychainHelper.shared.delete(service: "com.chettinadcare.auth", account: "session") }
}
public actor SessionManager {
    public static let shared = SessionManager()
    
    private let storage: any AuthSessionStorage
    private var generation = 0
    private var refreshGeneration: Int?
    
    private var currentSession: AuthSession?
    private var refreshTask: Task<AuthSession, Error>?
    
    public init(storage: any AuthSessionStorage = KeychainSessionStorage()) {
        self.storage = storage
        if let data = storage.read(),
           let session = try? JSONDecoder().decode(AuthSession.self, from: data) {
            self.currentSession = session
        }
    }
    
    public enum SessionError: Error {
        case persistenceFailed
    }
    
    public func saveSession(_ session: AuthSession) throws {
        guard let data = try? JSONEncoder().encode(session),
              storage.save(data) else {
            throw SessionError.persistenceFailed
        }
        generation += 1
        refreshTask?.cancel(); refreshTask = nil; refreshGeneration = nil
        self.currentSession = session
    }
    
    public func logout(apiClient: APIClient) async {
        refreshTask?.cancel()
        refreshTask = nil
        do {
            let endpoint = LogoutEndpoint()
            let _: [String: String]? = try? await apiClient.executeRaw(endpoint: endpoint)
        }
        clearSession()
    }
    
    public func clearSession() {
        refreshTask?.cancel()
        refreshTask = nil
        generation += 1; refreshGeneration = nil
        self.currentSession = nil
        storage.delete()
        if let cookies = HTTPCookieStorage.shared.cookies {
            for cookie in cookies {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
        Task { @MainActor in
            NotificationCenter.default.post(name: .chettinadSessionEnded, object: nil)
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
        
        guard let original = currentSession else { throw APIError.unauthenticated }
        let expectedGeneration = generation
        refreshGeneration = expectedGeneration
        let task = Task { () -> AuthSession in
            defer { if self.refreshGeneration == expectedGeneration { self.refreshTask = nil; self.refreshGeneration = nil } }
            do {
                let response: RefreshResponse = try await apiClient.executeRaw(
                    endpoint: RefreshEndpoint()
                )
                
                guard let current = self.currentSession, self.generation == expectedGeneration,
                      current.userId == original.userId, current.accessToken == original.accessToken,
                      response.userId == original.userId,
                      response.role.uppercased() == original.role.uppercased(),
                      response.account_type.uppercased() == original.accountType.uppercased() else {
                    throw APIError.unauthenticated
                }
                
                let newSession = AuthSession(
                    accessToken: response.access_token,
                    role: response.role,
                    accountType: response.account_type,
                    userId: current.userId,
                    name: current.name
                )
                guard let data = try? JSONEncoder().encode(newSession), self.storage.save(data) else { throw SessionError.persistenceFailed }
                self.currentSession = newSession
                return newSession
            } catch {
                // Only a rejected refresh ends the session; offline/timeouts keep the user signed in.
                if self.generation == expectedGeneration && Self.shouldEndSession(after: error) {
                    self.clearSession()
                }
                throw error
            }
        }
        
        self.refreshTask = task
        return try await task.value
    }

    private static func shouldEndSession(after error: Error) -> Bool {
        guard let apiError = error as? APIError else { return false }
        if case .unauthenticated = apiError { return true }
        return apiError.isUnauthorized
    }
}

struct RefreshEndpoint: APIEndpoint {
    var path: String { "/api/v1/auth/refresh" }
    var method: HTTPMethod { .post }
}

struct RefreshResponse: Codable {
    let userId: String
    let access_token: String
    let role: String
    let account_type: String
}

public struct SessionInfo: Codable, Identifiable {
    public let id: String
    public let device_name: String?
    public let current: Bool
    public let expires_at: String
}

public struct GetSessionsEndpoint: APIEndpoint {
    public typealias Response = [SessionInfo]
    public var path: String { "/api/v1/auth/opd/sessions" }
    public var method: HTTPMethod { .get }
    public init() {}
}

public struct RevokeSessionEndpoint: APIEndpoint {
    public typealias Response = [String: String]
    public let sessionId: String
    public var path: String { "/api/v1/auth/opd/sessions/\(sessionId)" }
    public var method: HTTPMethod { .delete }
    public init(sessionId: String) { self.sessionId = sessionId }
}
