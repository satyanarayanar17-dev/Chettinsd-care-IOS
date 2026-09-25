import Foundation

public final class APIClient: @unchecked Sendable {
    public let baseURL: URL
    private let urlSession: URLSession
    
    public init(baseURL: URL = EnvironmentConfig.current.baseURL, urlSession: URLSession? = nil) {
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
            let isAuthRoute = endpoint.path.contains("/auth/login") || endpoint.path.contains("/auth/opd/otp") || endpoint.path.contains("/auth/refresh")
            if error.isUnauthorized && retryCount > 0 && !isAuthRoute {
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
        outputStream.open()
        
        func writeString(_ text: String) throws {
            let data = text.data(using: .utf8)!
            let written = data.withUnsafeBytes { outputStream.write($0.bindMemory(to: UInt8.self).baseAddress!, maxLength: data.count) }
            if written < 0 { throw APIError.invalidResponse }
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
                if written < 0 { throw APIError.invalidResponse }
                totalWritten += written
            }
        }
        inputStream.close()
        
        try writeString("\r\n--\(boundary)--\r\n")
        outputStream.close()
        
        defer { try? FileManager.default.removeItem(at: tempFileURL) }
        
        let path = "/api/v1/opd/patient-documents/\(patientId)"
        guard let url = URL(string: path, relativeTo: baseURL) else { throw APIError.invalidResponse }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(await SessionManager.shared.getAccessToken() ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Correlation-ID")
        
        let (data, response) = try await urlSession.upload(for: request, fromFile: tempFileURL)
        
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
        guard let url = URL(string: document.content_url, relativeTo: baseURL) else { throw APIError.invalidResponse }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(await SessionManager.shared.getAccessToken() ?? "")", forHTTPHeaderField: "Authorization")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Correlation-ID")
        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { throw APIError.invalidResponse }
        let safeExtension = document.original_filename.split(separator: ".").last.map(String.init) ?? (document.mime_type == "application/pdf" ? "pdf" : "bin")
        let destination = FileManager.default.temporaryDirectory.appendingPathComponent("\(document.id).\(safeExtension)")
        try data.write(to: destination, options: .atomic)
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
