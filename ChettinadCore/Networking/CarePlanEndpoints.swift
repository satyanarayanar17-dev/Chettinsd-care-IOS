import Foundation

public struct GetCarePlanEndpoint: APIEndpoint, Sendable {
    public var path: String { "/api/v1/opd/care-plans/\(patientId)" }
    public var method: HTTPMethod { .get }
    
    public let patientId: String
    
    public init(patientId: String) {
        self.patientId = patientId
    }
}

public struct GetTodayAdherenceEndpoint: APIEndpoint, Sendable {
    public var path: String { "/api/v1/opd/adherence/\(patientId)/today" }
    public var method: HTTPMethod { .get }
    
    public let patientId: String
    
    public init(patientId: String) {
        self.patientId = patientId
    }
}

public struct GetTimelineEndpoint: APIEndpoint, Sendable {
    public var path: String { "/api/v1/opd/adherence/\(patientId)/timeline" }
    public var method: HTTPMethod { .get }
    
    public let patientId: String
    
    public init(patientId: String) {
        self.patientId = patientId
    }
}

public struct RecordAdherenceEndpoint: APIEndpoint, Sendable {
    public var path: String { "/api/v1/opd/adherence/\(resourceId)/record" }
    public var method: HTTPMethod { .post }
    public var body: Data? {
        try? JSONEncoder().encode(payload)
    }
    
    public let resourceId: String
    public let payload: RecordAdherencePayload
    
    public init(resourceId: String, payload: RecordAdherencePayload) {
        self.resourceId = resourceId
        self.payload = payload
    }
}
