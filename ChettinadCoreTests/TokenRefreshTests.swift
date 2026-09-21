import XCTest
@testable import ChettinadCore

final class TokenRefreshTests: XCTestCase {
    
    func testSingleFlightRefresh() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)
        let client = APIClient(urlSession: urlSession)
        
        let manager = SessionManager.shared
        await manager.clearSession()
        let session = AuthSession(accessToken: "old_token", role: "PATIENT", accountType: "PATIENT", userId: "1", name: "Test")
        await manager.saveSession(session)
        
        class MockServer: @unchecked Sendable {
            private var _refreshCount = 0
            private var _retryCount = 0
            private let lock = NSLock()
            
            func handle(request: URLRequest) -> (HTTPURLResponse, Data?) {
                lock.lock()
                defer { lock.unlock() }
                let path = request.url?.path ?? ""
                if path.contains("/auth/refresh") {
                    _refreshCount += 1
                    let json = """
                    {"access_token": "new_token", "role": "PATIENT", "account_type": "PATIENT"}
                    """
                    return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json.data(using: .utf8)!)
                } else if path.contains("/test") {
                    if request.value(forHTTPHeaderField: "Authorization") == "Bearer old_token" {
                        return (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, Data())
                    } else {
                        _retryCount += 1
                        let json = """
                        {"id": "success"}
                        """
                        return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, json.data(using: .utf8)!)
                    }
                }
                return (HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!, Data())
            }
            
            func getRefreshCount() -> Int { lock.lock(); defer { lock.unlock() }; return _refreshCount }
            func getRetryCount() -> Int { lock.lock(); defer { lock.unlock() }; return _retryCount }
        }
        
        let mockServer = MockServer()
        
        MockURLProtocol.requestHandler = { request in
            Thread.sleep(forTimeInterval: 0.1) // simulate delay
            return mockServer.handle(request: request)
        }
        
        struct TestEndpoint: APIEndpoint {
            var path: String = "/test"
            var method: HTTPMethod = .get
        }
        
        struct TestResponse: Codable {
            let id: String
        }
        
        // Fire 3 simultaneous requests
        async let r1: TestResponse = client.execute(endpoint: TestEndpoint())
        async let r2: TestResponse = client.execute(endpoint: TestEndpoint())
        async let r3: TestResponse = client.execute(endpoint: TestEndpoint())
        
        let results = try await [r1, r2, r3]
        
        XCTAssertEqual(results.count, 3)
        for r in results {
            XCTAssertEqual(r.id, "success")
        }
        
        let refreshCount = mockServer.getRefreshCount()
        let retryCount = mockServer.getRetryCount()
        
        XCTAssertEqual(refreshCount, 1, "Should only refresh once")
        XCTAssertEqual(retryCount, 3, "All 3 requests should be retried with the new token")
        
        let finalToken = await manager.getAccessToken()
        XCTAssertEqual(finalToken, "new_token")
    }
    
    func testSessionParsing() throws {
        let json = """
        {
            "id": "123",
            "name": "Test",
            "role": "DOCTOR",
            "department": "Cardiology",
            "must_change_password": false
        }
        """
        let session = try JSONDecoder().decode(UserSession.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(session.role, "DOCTOR")
        XCTAssertEqual(session.name, "Test")
    }

    func testStaleStateError() throws {
        let jsonError = """
        {
            "error": {
                "code": "STALE_STATE",
                "message": "STALE_STATE"
            },
            "meta": {
                "correlation_id": "123"
            }
        }
        """
        let response = try JSONDecoder().decode(APIErrorResponse.self, from: jsonError.data(using: .utf8)!)
        XCTAssertEqual(response.error.code, "STALE_STATE")
    }
}
