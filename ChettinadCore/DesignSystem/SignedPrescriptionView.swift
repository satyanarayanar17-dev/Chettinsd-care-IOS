import SwiftUI
import UIKit

public struct SignedPrescriptionView: View {
    public let prescription: Prescription
    public let patient: Patient
    @State private var exportURL: URL?
    @State private var error: String?
    public init(prescription: Prescription, patient: Patient) { self.prescription = prescription; self.patient = patient }
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Chettinad Care · Prescription").font(.headline)
            Text("\(prescription.rx_content?.patient_snapshot?.name ?? patient.name) · MRN \(prescription.rx_content?.patient_snapshot?.mrn ?? patient.mrn) · DOB \(prescription.rx_content?.patient_snapshot?.dob ?? patient.dob)")
            Text("\(prescription.doctor_name ?? prescription.authorizing_user_id) · \(ISODate.display(prescription.rx_content?.validation?.issued_at ?? prescription.created_at))").font(.caption)
            Text("Prescription \(prescription.id) · version \(prescription.__v ?? 1)").font(.caption)
            if let content = prescription.rx_content {
                Text(content.diagnoses?.map(\.name).joined(separator: ", ") ?? "Diagnosis not recorded")
                ForEach(Array((content.medications ?? []).enumerated()), id: \.offset) { _, med in
                    VStack(alignment: .leading) {
                        Text("\(med.name) · \(med.strength) · \(med.form) · \(med.route)").font(.headline)
                        Text("\(med.dose) · \(med.frequency) · \(med.duration)")
                        if let instructions = med.instructions { Text(instructions) }
                    }
                }
                if let advice = content.advice { Text(advice) }
                if let follow = content.follow_up { Text("Follow-up: \(ISODate.display(follow.scheduled_at)) · \(follow.reason)") }
            }
            if let error { Text(error).foregroundStyle(.red) }
            if prescription.status == "AUTHORIZED" {
                Button("Prepare prescription PDF") {
                    do {
                        if let exportURL { try? FileManager.default.removeItem(at: exportURL) }
                        exportURL = try PrescriptionPDF.create(prescription: prescription, patient: patient); error = nil
                    } catch { self.error = "The prescription could not be prepared. Please try again." }
                }
                if let exportURL {
                    ShareLink("Share / save prescription PDF", item: exportURL)
                    Button("Print prescription") {
                        let controller = UIPrintInteractionController.shared
                        let info = UIPrintInfo(dictionary: nil); info.outputType = .general; info.jobName = "Chettinad prescription"
                        controller.printInfo = info; controller.printingItem = exportURL
                        controller.present(animated: true)
                    }
                }
            }
        }.padding().navigationTitle("Prescription")
        .onDisappear { if let exportURL { try? FileManager.default.removeItem(at: exportURL); self.exportURL = nil } }
    }
}
@MainActor
public enum PrescriptionPDF {
    public static func content(prescription: Prescription, patient: Patient) -> String {
        let snapshot=prescription.rx_content?.patient_snapshot
        let allergies = snapshot == nil ? patient.allergies : snapshot?.allergies
        let allergyStatus = snapshot == nil ? patient.allergy_review_status : snapshot?.allergy_review_status
        var lines = ["CHETTINAD CARE", "Authorised prescription", "Patient: \(snapshot?.name ?? patient.name)", "MRN: \(snapshot?.mrn ?? patient.mrn)    DOB: \(snapshot?.dob ?? patient.dob)    Gender: \(snapshot?.gender ?? patient.gender)", "Allergies: \(allergies?.isEmpty == false ? allergies! : (allergyStatus == "NONE_REPORTED" ? "None reported" : "Not recorded"))", "Doctor: \(prescription.doctor_name ?? prescription.authorizing_user_id)", "Issued: \(ISODate.display(prescription.rx_content?.validation?.issued_at ?? prescription.created_at))", "Prescription: \(prescription.id)    Version: \(prescription.__v ?? 1)", "Visit: \(prescription.encounter_id)", ""]
        if let content = prescription.rx_content {
            lines += ["Diagnoses: \(content.diagnoses?.map(\.name).joined(separator: ", ") ?? "Not recorded")", "", "MEDICATIONS"]
            for (index, med) in (content.medications ?? []).enumerated() {
                lines += ["\(index + 1). \(med.name) · \(med.strength) · \(med.form) · \(med.route)", "Dose: \(med.dose)    Frequency: \(med.frequency)    Duration: \(med.duration)", "Instructions: \(med.instructions ?? "")", ""]
            }
            lines += ["ADVICE", content.advice ?? ""]
            if let follow = content.follow_up { lines += ["", "FOLLOW-UP", "\(ISODate.display(follow.scheduled_at)) · \(follow.reason)"] }
            lines += ["", "Signed by: \(content.validation?.signed_by ?? prescription.authorizing_user_id)", "Record hash: \(content.validation?.sha256 ?? "Unavailable")"]
        }
        return lines.joined(separator: "\n")
    }
    public static func create(prescription: Prescription, patient: Patient) throws -> URL {
        guard prescription.status == "AUTHORIZED", prescription.rx_content?.patient_snapshot?.id == nil || prescription.rx_content?.patient_snapshot?.id == patient.id else { throw APIError.invalidResponse }
        let renderer = PrescriptionPageRenderer()
        let formatter = UISimpleTextPrintFormatter(attributedText: NSAttributedString(string: content(prescription: prescription, patient: patient), attributes: [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.black]))
        renderer.addPrintFormatter(formatter, startingAtPageAt: 0)
        renderer.prepare(forDrawingPages: NSRange(location: 0, length: renderer.numberOfPages))
        let pdf = UIGraphicsPDFRenderer(bounds: renderer.paperRect).pdfData { context in
            for index in 0..<renderer.numberOfPages { context.beginPage(); renderer.drawPage(at: index, in: renderer.paperRect) }
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Prescription-\(UUID().uuidString).pdf")
        try pdf.write(to: url, options: [.atomic, .completeFileProtection]); return url
    }
}
@MainActor
private final class PrescriptionPageRenderer: UIPrintPageRenderer {
    override var paperRect: CGRect { CGRect(x: 0, y: 0, width: 595, height: 842) }
    override var printableRect: CGRect { paperRect.insetBy(dx: 36, dy: 36) }
}
