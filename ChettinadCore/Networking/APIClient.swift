import Foundation

public final class APIClient: @unchecked Sendable {
    public let baseURL: URL
    private let urlSession: URLSession
    public let sessionManager: SessionManager
    
    public init(baseURL: URL = EnvironmentConfig.current.baseURL, urlSession: URLSession? = nil, sessionManager: SessionManager = .shared) {
        self.sessionManager = sessionManager
        self.baseURL = baseURL
        if let urlSession {
            self.urlSession = urlSession
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 30.0
            config.timeoutIntervalForResource = 300.0
            self.urlSession = URLSession(configuration: config)
        }
    }
    
    public func execute<T: Codable>(endpoint: APIEndpoint) async throws -> T {
        return try await executeWithRetry(endpoint: endpoint, retryCount: 1)
    }
    
    private func executeWithRetry<T: Codable>(endpoint: APIEndpoint, retryCount: Int) async throws -> T {
        do {
            return try await executeInternal(endpoint: endpoint)
        } catch let error as APIError {
            let isAuthRoute = endpoint.path.contains("/auth/login") || endpoint.path.contains("/auth/opd/otp") || endpoint.path.contains("/auth/refresh") || endpoint.path.hasSuffix("/auth/change-password")
            if error.isUnauthorized && retryCount > 0 && !isAuthRoute {
                // Attempt refresh
                _ = try await sessionManager.refreshToken(apiClient: self)
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
        
        if let token = await sessionManager.getAccessToken() {
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

    public func uploadPatientDocument(patientId: String, fileURL: URL, title: String, documentType: String, clinicalDate: String, appointmentId: String?, note: String?) async throws -> PatientDocument {
        let didAccess = fileURL.startAccessingSecurityScopedResource()
        defer { if didAccess { fileURL.stopAccessingSecurityScopedResource() } }
        
        let attr = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let fileSize = attr[.size] as? UInt64 ?? 0
        guard fileSize <= 10 * 1024 * 1024 else { throw APIError.invalidResponse } // 10MB limit
        
        let mimeType: String
        switch fileURL.pathExtension.lowercased() {
        case "pdf": mimeType = "application/pdf"
        case "jpg", "jpeg": mimeType = "image/jpeg"
        case "png": mimeType = "image/png"
        default: throw APIError.invalidResponse // Invalid file type
        }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileURL = tempDir.appendingPathComponent(UUID().uuidString)
        
        guard let outputStream = OutputStream(url: tempFileURL, append: false) else { throw APIError.invalidResponse }
        guard FileManager.default.createFile(atPath:tempFileURL.path,contents:nil,attributes:[.protectionKey:FileProtectionType.complete,.posixPermissions:0o600]) else { throw APIError.invalidResponse }
        // Always remove the temporary copy of the medical document, even if we throw part-way through.
        defer { try? FileManager.default.removeItem(at: tempFileURL) }
        outputStream.open()
        var outputClosed = false
        defer { if !outputClosed { outputStream.close() } }
        
        func writeString(_ text: String) throws {
            let data = text.data(using: .utf8)!
            try data.withUnsafeBytes { bytes in
                guard let base = bytes.bindMemory(to:UInt8.self).baseAddress else { return }
                var offset=0
                while offset < data.count {
                    let written=outputStream.write(base.advanced(by:offset),maxLength:data.count-offset)
                    if written <= 0 { throw APIError.invalidResponse };offset += written
                }
            }
        }
        
        func field(_ name: String, _ value: String?) throws {
            guard let value, !value.isEmpty else { return }
            try writeString("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(name)\"\r\n\r\n\(value)\r\n")
        }
        
        try field("document_type", documentType)
        try field("title", title)
        try field("clinical_date", clinicalDate)
        try field("appointment_id", appointmentId)
        try field("patient_note", note)
        
        try writeString("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent.replacingOccurrences(of: "\"", with: ""))\"\r\nContent-Type: \(mimeType)\r\n\r\n")
        
        guard let inputStream = InputStream(url: fileURL) else { throw APIError.invalidResponse }
        inputStream.open()
        defer { inputStream.close() }
        let bufferSize = 65536
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        
        while inputStream.hasBytesAvailable {
            let read = inputStream.read(buffer, maxLength: bufferSize)
            if read < 0 { throw APIError.invalidResponse }
            if read == 0 { break }
            var totalWritten = 0
            while totalWritten < read {
                let written = outputStream.write(buffer.advanced(by: totalWritten), maxLength: read - totalWritten)
                if written <= 0 { throw APIError.invalidResponse }
                totalWritten += written
            }
        }
        
        try writeString("\r\n--\(boundary)--\r\n")
        outputStream.close()
        outputClosed = true
        
        let path = "/api/v1/opd/patient-documents/\(patientId)"
        guard let url = URL(string: path, relativeTo: baseURL) else { throw APIError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(await sessionManager.getAccessToken() ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Correlation-ID")
        
        var (data, response) = try await urlSession.upload(for: request, fromFile: tempFileURL)
        if (response as? HTTPURLResponse)?.statusCode == 401 {
            _ = try await sessionManager.refreshToken(apiClient:self)
            request.setValue("Bearer \(await sessionManager.getAccessToken() ?? "")",forHTTPHeaderField:"Authorization")
            (data,response) = try await urlSession.upload(for:request,fromFile:tempFileURL)
        }
        
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        if !(200...299).contains(http.statusCode) {
            if let apiResponse = try? JSONDecoder().decode(APIErrorResponse.self, from: data) {
                throw APIError.apiError(statusCode: http.statusCode, response: apiResponse)
            }
            throw APIError.httpError(statusCode: http.statusCode, data: data)
        }
        
        return try JSONDecoder().decode(PatientDocument.self, from: data)
    }

    public func downloadPatientDocument(_ document: PatientDocument) async throws -> URL {
        guard let url = URL(string:document.content_url,relativeTo:baseURL)?.absoluteURL,
              url.scheme == baseURL.scheme, url.host == baseURL.host, url.port == baseURL.port,
              url.path.hasPrefix("/api/v1/opd/patient-documents/"), url.user == nil, url.password == nil else { throw APIError.invalidResponse }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(await sessionManager.getAccessToken() ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Correlation-ID")
        var (data,response) = try await urlSession.data(for:request)
        if (response as? HTTPURLResponse)?.statusCode == 401 {
            _ = try await sessionManager.refreshToken(apiClient:self)
            request.setValue("Bearer \(await sessionManager.getAccessToken() ?? "")",forHTTPHeaderField:"Authorization")
            (data,response) = try await urlSession.data(for:request)
        }
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { throw APIError.invalidResponse }
        guard let safeExtension = ["application/pdf":"pdf","image/jpeg":"jpg","image/png":"png"][document.mime_type] else { throw APIError.invalidResponse }
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("Medical-document-\(UUID().uuidString).\(safeExtension)")
        // Protected at rest; callers delete the file once the preview is dismissed.
        try data.write(to: destination, options: [.atomic, .completeFileProtection])
        return destination
    }
}

private struct MultipartEndpoint: APIEndpoint {
    let path: String
    let boundary: String
    let body: Data?
    var method: HTTPMethod { .post }
    var headers: [String: String]? { ["Content-Type": "multipart/form-data; boundary=\(boundary)"] }
}
