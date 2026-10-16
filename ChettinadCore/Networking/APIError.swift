import Foundation

public struct APIErrorResponse: Codable, Error {
    public struct ErrorDetail: Codable, Sendable {
        public let code: String
        public let message: String
        // Details could be Any, but Codable doesn't support Any directly, so we can use a dictionary if needed, or leave it out if we don't strictly need to parse it yet.
    }
    
    public struct MetaDetail: Codable, Sendable {
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
    case apiError(statusCode: Int, response: APIErrorResponse)
    case decodingError(Error)
    case unauthenticated
}

extension APIError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .networkError(let error as NSError) where error.domain == NSURLErrorDomain && error.code == NSURLErrorNotConnectedToInternet:
            return "Please check your internet connection and try again."
        case .networkError(let error as NSError) where error.domain == NSURLErrorDomain && error.code == NSURLErrorTimedOut:
            return "The request timed out. Please try again."
        case .networkError: 
            return "A network error occurred. Please try again."
        case .invalidResponse: 
            return "Received an unexpected response from the server."
        case .httpError(let statusCode, _): 
            return statusCode >= 500 ? "Server is temporarily unavailable. Please try again later." : "Something went wrong (Error \(statusCode))."
        case .apiError(_, let response):
            switch response.error.code {
            case "VISIT_HANDOVER_REQUIRED": return "Clinical work has started. Follow the hospital's clinician handover procedure."
            case "PATIENT_RECORD_CHANGED": return "Patient details changed. Review the updated identity and allergies before signing."
            case "PATIENT_REVIEW_REQUIRED": return "Load and review the patient record before signing."
            case "STALE_STATE": return "This record changed elsewhere. Refresh and review the latest version before retrying."
            default: break
            }
            return response.error.message.isEmpty ? "An unexpected error occurred." : response.error.message
        case .decodingError: 
            return "There was a problem loading the data."
        case .unauthenticated: 
            return "Your session has expired. Please log in again."
        }
    }
    
    public var isUnauthorized: Bool {
        switch self {
        case .httpError(let statusCode, _):
            return statusCode == 401
        case .apiError(let statusCode, _):
            return statusCode == 401
        default:
            return false
        }
    }
}
