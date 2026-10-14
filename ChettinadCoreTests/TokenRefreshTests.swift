import XCTest
@testable import ChettinadCore

final class TokenRefreshTests: XCTestCase {
    
    func testSingleFlightRefresh() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let urlSession = URLSession(configuration: configuration)
        let manager = SessionManager(storage:MemorySessionStorage())
        let client = APIClient(urlSession:urlSession,sessionManager:manager)
        await manager.clearSession()
        let session = AuthSession(accessToken: "old_token", role: "PATIENT", accountType: "PATIENT", userId: "1", name: "Test")
        try await manager.saveSession(session)
        
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
                    {"access_token": "new_token", "role": "PATIENT", "account_type": "PATIENT", "userId": "1"}
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
            "role": "PATIENT",
            "department": null,
            "patient_id": "patient-123",
            "must_change_password": 0
        }
        """
        let session = try JSONDecoder().decode(UserSession.self, from: json.data(using: .utf8)!)
        XCTAssertEqual(session.role, "PATIENT")
        XCTAssertEqual(session.name, "Test")
        XCTAssertEqual(session.patient_id, "patient-123")
        XCTAssertFalse(session.must_change_password)
    }

    func testStructured401RefreshesOnceAndRetriesOriginalRequest() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let manager = SessionManager(storage:MemorySessionStorage())
        let client = APIClient(urlSession:URLSession(configuration:configuration),sessionManager:manager)
        await manager.clearSession()
        try await manager.saveSession(AuthSession(accessToken: "expired", role: "PATIENT", accountType: "PATIENT", userId: "p1", name: "Patient"))

        final class Counts: @unchecked Sendable {
            let lock = NSLock()
            var refresh = 0
            var resource = 0
        }
        let counts = Counts()
        MockURLProtocol.requestHandler = { request in
            counts.lock.lock(); defer { counts.lock.unlock() }
            let path = request.url!.path
            if path.contains("/auth/refresh") {
                counts.refresh += 1
                let data = Data(#"{"access_token":"fresh","role":"patient","account_type":"patient","userId":"p1"}"#.utf8)
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, data)
            }
            counts.resource += 1
            if request.value(forHTTPHeaderField: "Authorization") == "Bearer expired" {
                let data = Data(#"{"error":{"code":"TOKEN_EXPIRED","message":"Expired"},"meta":{"correlation_id":"test"}}"#.utf8)
                return (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, data)
            }
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, Data(#"{"id":"ok"}"#.utf8))
        }

        struct Endpoint: APIEndpoint { let path = "/structured-401"; let method: HTTPMethod = .get }
        struct Response: Codable { let id: String }
        let response: Response = try await client.execute(endpoint: Endpoint())
        XCTAssertEqual(response.id, "ok")
        XCTAssertEqual(counts.refresh, 1)
        XCTAssertEqual(counts.resource, 2)
    }

    func testFailedRefreshClearsSessionWithoutRetryLoop() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let manager = SessionManager(storage:MemorySessionStorage())
        let client = APIClient(urlSession:URLSession(configuration:configuration),sessionManager:manager)
        await manager.clearSession()
        try await manager.saveSession(AuthSession(accessToken: "expired", role: "PATIENT", accountType: "PATIENT", userId: "p1", name: "Patient"))

        final class Counts: @unchecked Sendable {
            let lock = NSLock()
            var refresh = 0
            var resource = 0
        }
        let counts = Counts()
        MockURLProtocol.requestHandler = { request in
            counts.lock.lock(); defer { counts.lock.unlock() }
            if request.url!.path.contains("/auth/refresh") {
                counts.refresh += 1
            } else {
                counts.resource += 1
            }
            let data = Data(#"{"error":{"code":"REFRESH_INVALID","message":"Sign in again"},"meta":{"correlation_id":"test"}}"#.utf8)
            return (HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!, data)
        }

        struct Endpoint: APIEndpoint { let path = "/requires-auth"; let method: HTTPMethod = .get }
        struct Response: Codable { let id: String }
        do {
            let _: Response = try await client.execute(endpoint: Endpoint())
            XCTFail("Expected refresh failure")
        } catch { }
        XCTAssertEqual(counts.refresh, 1)
        XCTAssertEqual(counts.resource, 1)
        let clearedSession = await manager.getSession()
        XCTAssertNil(clearedSession)
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

final class MemorySessionStorage: AuthSessionStorage, @unchecked Sendable {
    private let lock = NSLock(); private var value: Data?
    func read() -> Data? { lock.lock(); defer { lock.unlock() }; return value }
    func save(_ data: Data) -> Bool { lock.lock(); defer { lock.unlock() }; value = data; return true }
    func delete() { lock.lock(); defer { lock.unlock() }; value = nil }
}

extension TokenRefreshTests {
    func testLateRefreshCannotReplaceANewerLogin() async throws {
        let manager = SessionManager(storage:MemorySessionStorage())
        let config = URLSessionConfiguration.ephemeral;config.protocolClasses=[MockURLProtocol.self]
        let client = APIClient(urlSession:URLSession(configuration:config),sessionManager:manager)
        try await manager.saveSession(AuthSession(accessToken:"old",role:"PATIENT",accountType:"PATIENT",userId:"old-user",name:nil))
        let entered = expectation(description:"Refresh entered")
        MockURLProtocol.requestHandler = { request in
            entered.fulfill();Thread.sleep(forTimeInterval:0.2)
            return (HTTPURLResponse(url:request.url!,statusCode:200,httpVersion:nil,headerFields:nil)!,Data(#"{"userId":"old-user","access_token":"late-old-token","role":"PATIENT","account_type":"PATIENT"}"#.utf8))
        }
        let refresh = Task { try await manager.refreshToken(apiClient:client) }
        await fulfillment(of:[entered],timeout:1)
        try await manager.saveSession(AuthSession(accessToken:"new-login",role:"PATIENT",accountType:"PATIENT",userId:"new-user",name:nil))
        do { _ = try await refresh.value;XCTFail("A stale response must be rejected") } catch {}
        let current = await manager.getSession();XCTAssertEqual(current?.userId,"new-user");XCTAssertEqual(current?.accessToken,"new-login")
    }
    func testRefreshForAnotherAccountEndsTheInvalidSession() async throws {
        let manager = SessionManager(storage:MemorySessionStorage())
        let config=URLSessionConfiguration.ephemeral;config.protocolClasses=[MockURLProtocol.self]
        let client=APIClient(urlSession:URLSession(configuration:config),sessionManager:manager)
        try await manager.saveSession(AuthSession(accessToken:"old",role:"PATIENT",accountType:"PATIENT",userId:"my-user",name:nil))
        MockURLProtocol.requestHandler={ request in (HTTPURLResponse(url:request.url!,statusCode:200,httpVersion:nil,headerFields:nil)!,Data(#"{"userId":"another-user","access_token":"wrong-token","role":"PATIENT","account_type":"PATIENT"}"#.utf8)) }
        do { _ = try await manager.refreshToken(apiClient:client);XCTFail("Wrong account must be rejected") } catch {}
        let current=await manager.getSession();XCTAssertNil(current)
    }
}
