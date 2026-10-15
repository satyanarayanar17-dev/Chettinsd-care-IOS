import XCTest
@testable import ChettinadCore

final class SharedClientContractTests: XCTestCase {
    func testDocumentDetachmentSendsExplicitNull() throws {
        let endpoint = LinkPatientDocumentAppointmentEndpoint(patientId: "patient", documentId: "document", appointmentId: nil)
        let body = try XCTUnwrap(try JSONSerialization.jsonObject(with: XCTUnwrap(endpoint.body)) as? [String: Any])
        XCTAssertTrue(body["appointment_id"] is NSNull)
    }
    func testEnvironmentUsesConfiguredBackendAndNormalizesAPIPrefix() throws {
        XCTAssertEqual(try EnvironmentConfig.resolveAPIBaseURL(environment: .staging, configuredValue: "https://synthetic.example/api/v1/").absoluteString, "https://synthetic.example")
        XCTAssertThrowsError(try EnvironmentConfig.resolveAPIBaseURL(environment: .production, configuredValue: "http://127.0.0.1:3005"))
        XCTAssertEqual(try EnvironmentConfig.resolveAPIBaseURL(environment: .local, configuredValue: "http://127.0.0.1:3005").host, "127.0.0.1")
    }
}
