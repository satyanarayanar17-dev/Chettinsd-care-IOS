import Foundation

public final class APIClient: @unchecked Sendable {
    public let baseURL: URL
    private let urlSession: URLSession
    
    public init(baseURL: URL = EnvironmentConfig.current.baseURL, urlSession: URLSession = .shared) {
        self.baseURL = baseURL
        self.urlSession = urlSession
    }
    
    public func execute<T: Codable>(endpoint: APIEndpoint) async throws -> T {
        return try await executeWithRetry(endpoint: endpoint, retryCount: 1)
    }
    
    private func executeWithRetry<T: Codable>(endpoint: APIEndpoint, retryCount: Int) async throws -> T {
        do {
            return try await executeInternal(endpoint: endpoint)
        } catch let error as APIError {
            if error.isUnauthorized && retryCount > 0 {
                // Attempt refresh
                _ = try await SessionManager.shared.refreshToken(apiClient: self)
                return try await executeWithRetry(endpoint: endpoint, retryCount: retryCount - 1)
            }
            throw error
        } catch {
            throw error
        }
    }
    
    /// Executes without token refresh logic, for use inside SessionManager
    internal func executeRaw<T: Codable>(endpoint: APIEndpoint) async throws -> T {
        return try await executeInternal(endpoint: endpoint)
    }
    
    private func executeInternal<T: Codable>(endpoint: APIEndpoint) async throws -> T {
        guard var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false) else {
            throw APIError.invalidResponse
        }
        
        if let queryItems = endpoint.queryItems {
            components.queryItems = queryItems
        }
        
        guard let url = components.url else {
            throw APIError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let correlationId = UUID().uuidString
        request.setValue(correlationId, forHTTPHeaderField: "X-Correlation-ID")
        
        if let token = await SessionManager.shared.getAccessToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let headers = endpoint.headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        if let body = endpoint.body {
            request.httpBody = body
        }
        
        let (data, response) = try await urlSession.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if !(200...299).contains(httpResponse.statusCode) {
            if let apiErrorResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw APIError.apiError(statusCode: httpResponse.statusCode, response: apiErrorResponse)
            }
            throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
        }
        
        do {
            let decoded = try JSONDecoder().decode(T.self, from: data)
            return decoded
        } catch {
            throw APIError.decodingError(error)
        }
    }
}
