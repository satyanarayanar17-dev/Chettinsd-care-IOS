import Foundation

public struct DirectoryEndpoint: APIEndpoint, Sendable {
    public var path: String { "/api/v1/opd/directory" }
    public var method: HTTPMethod { .get }
    public init() {}
}

public struct AppointmentSlotsEndpoint: APIEndpoint, Sendable {
    public let doctorId: String
    public let date: String
    public var path: String { "/api/v1/opd/slots" }
    public var method: HTTPMethod { .get }
    public var queryItems: [URLQueryItem]? { [.init(name: "doctor_id", value: doctorId), .init(name: "date", value: date)] }
    public init(doctorId: String, date: String) { self.doctorId = doctorId; self.date = date }
}

public struct BookAppointmentEndpoint: APIEndpoint, Sendable {
    public let doctorId: String
    public let scheduledAt: String
    public let reason: String
    public var path: String { "/api/v1/opd/appointments" }
    public var method: HTTPMethod { .post }
    public var body: Data? { try? JSONEncoder().encode(Payload(doctor_id: doctorId, scheduled_at: scheduledAt, reason: reason)) }
    private struct Payload: Encodable { let doctor_id: String; let scheduled_at: String; let reason: String }
    public init(doctorId: String, scheduledAt: String, reason: String) { self.doctorId = doctorId; self.scheduledAt = scheduledAt; self.reason = reason }
}

public struct PatientSelfRecordsEndpoint: APIEndpoint, Sendable {
    public let patientId: String
    public var path: String { "/api/v1/opd/patient-self-records/\(patientId)" }
    public var method: HTTPMethod { .get }
    public init(patientId: String) { self.patientId = patientId }
}

public struct CreatePatientSelfRecordEndpoint: APIEndpoint, Sendable {
    public let patientId: String
    public let payload: Data
    public var path: String { "/api/v1/opd/patient-self-records/\(patientId)" }
    public var method: HTTPMethod { .post }
    public var body: Data? { payload }
    public init<T: Encodable>(patientId: String, payload: T) throws { self.patientId = patientId; self.payload = try JSONEncoder().encode(payload) }
}

public struct PatientDocumentsEndpoint: APIEndpoint, Sendable {
    public let patientId: String
    public var path: String { "/api/v1/opd/patient-documents/\(patientId)" }
    public var method: HTTPMethod { .get }
    public init(patientId: String) { self.patientId = patientId }
}

public struct LinkPatientDocumentAppointmentEndpoint: APIEndpoint, Sendable {
    public let patientId: String
    public let documentId: String
    public let appointmentId: String?
    public var path: String { "/api/v1/opd/patient-documents/\(patientId)/\(documentId)/appointment" }
    public var method: HTTPMethod { .patch }
    public var body: Data? { try? JSONEncoder().encode(Payload(appointment_id: appointmentId)) }
    private struct Payload: Encodable {
        let appointment_id: String?
        enum CodingKeys: String, CodingKey { case appointment_id }
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            if let appointment_id { try container.encode(appointment_id, forKey: .appointment_id) }
            else { try container.encodeNil(forKey: .appointment_id) }
        }
    }
    public init(patientId: String, documentId: String, appointmentId: String?) {
        self.patientId = patientId
        self.documentId = documentId
        self.appointmentId = appointmentId
    }
}
