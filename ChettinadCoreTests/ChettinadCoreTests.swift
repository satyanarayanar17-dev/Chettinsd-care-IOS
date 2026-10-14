import XCTest
import PDFKit
@testable import ChettinadCore

@MainActor
final class NativeRecordContractTests: XCTestCase {
    func testUnsafeAndWrongEnvironmentURLsAreRejected() {
        for value in ["http://api.invalid","https://u:p@api.invalid","https://api.invalid/path","https://api.invalid?token=x","https://api.invalid#x", ""] { XCTAssertNil(EnvironmentConfig.resolveBaseURL(value,environment:.production)) }
        XCTAssertEqual(EnvironmentConfig.resolveBaseURL("https://approved.invalid",environment:.staging)?.host,"approved.invalid")
        XCTAssertNotNil(EnvironmentConfig.resolveBaseURL("http://127.0.0.1:3011",environment:.local))
    }
    func testStructuredLabResultDecodesAndPreservesAttribution() throws {
        let result = try JSONDecoder().decode(LabOrder.self,from:Data(#"{"id":"order","encounter_id":"visit","test_id":"test","ordered_by":"doctor","ordered_at":"2026-10-01T00:00:00Z","status":"AVAILABLE","__v":4,"result":{"id":"result","version":2,"value":"12.3","unit":"g/dL","reference_range":"Synthetic range","flag":"NORMAL","verified_name":"Synthetic verifier","resulted_at":"2026-10-01T01:00:00Z","released":1}}"#.utf8))
        XCTAssertEqual(result.result?.value,"12.3");XCTAssertEqual(result.result?.version,2);XCTAssertEqual(result.result?.released,true)
    }
    func testPrescriptionPDFPaginatesAndRetainsLongInstructionsAndIdentity() throws {
        let patient = try JSONDecoder().decode(Patient.self,from:Data(#"{"id":"p","mrn":"SYN-PDF","name":"Synthetic Print Patient","phone":"+919000000099","dob":"1990-01-01","gender":"Female","__v":1}"#.utf8))
        let medication: [String:Any] = ["drug_id":"drug","name":"Synthetic Medicine","strength":"1 unit","form":"Tablet","route":"Oral","dose":"1 tablet","frequency":"Once daily","duration":"3 days","instructions":String(repeating:"Synthetic long instruction for pagination. ",count:50)]
        let body: [String:Any] = ["id":"rx","encounter_id":"visit","status":"AUTHORIZED","authorizing_user_id":"doctor","created_at":"2026-10-01T00:00:00Z","__v":3,"rx_content":["medications":Array(repeating:medication,count:8),"advice":"Synthetic advice"]]
        let rx = try JSONDecoder().decode(Prescription.self,from:JSONSerialization.data(withJSONObject:body))
        let url = try PrescriptionPDF.create(prescription:rx,patient:patient);defer { try? FileManager.default.removeItem(at:url) }
        let pdf = try XCTUnwrap(PDFDocument(url:url));XCTAssertGreaterThan(pdf.pageCount,1)
        let text = (0..<pdf.pageCount).compactMap { pdf.page(at:$0)?.string }.joined(separator:"\n")
        XCTAssertTrue(text.contains("SYN-PDF"));XCTAssertTrue(text.contains("Version: 3"));XCTAssertTrue(text.contains("8. Synthetic Medicine"));XCTAssertTrue(text.contains("Synthetic advice"))
    }
}
