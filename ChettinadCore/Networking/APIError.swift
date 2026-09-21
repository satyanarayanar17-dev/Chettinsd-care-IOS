import Foundation

public struct APIErrorResponse: Codable, Error {
    public struct ErrorDetail: Codable {
        public let code: String
        public let message: String
        // Details could be Any, but Codable doesn't support Any directly, so we can use a dictionary if needed, or leave it out if we don't strictly need to parse it yet.
    }
    
    public struct MetaDetail: Codable {
        public let correlation_id: String?
    }
    
    public let error: ErrorDetail
    public let meta: MetaDetail?
    
    public init(error: ErrorDetail, meta: MetaDetail?) {
        self.error = error
        self.meta = meta
    }
}

public enum APIError: Error {
    case networkError(Error)
    case invalidResponse
    case httpError(statusCode: Int, data: Data?)
    case apiError(APIErrorResponse)
    case decodingError(Error)
    case unauthenticated
}
