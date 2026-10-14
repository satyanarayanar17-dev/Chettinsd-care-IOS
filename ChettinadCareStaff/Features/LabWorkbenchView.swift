import SwiftUI
import ChettinadCore

struct LabListEndpoint: APIEndpoint {
    var path: String { "/api/v1/opd/labs" }
    var method: HTTPMethod { .get }
}
struct LabActionEndpoint: APIEndpoint {
    let orderId: String
    let action: String
    let version: Int
    var data: [String: String] = [:]
    var released = false
    var path: String { "/api/v1/opd/labs/\(orderId)/\(action)" }
    var method: HTTPMethod { .post }
    var body: Data? {
        var payload: [String: Any] = ["__v": version]
        if action == "result" {
            var result: [String: Any] = data
            result["verified"] = true; result["released"] = released; payload["data"] = result
        }
        return try? JSONSerialization.data(withJSONObject: payload)
    }
}
@MainActor
final class LabWorkbenchViewModel: ObservableObject {
    @Published private(set) var orders: [LabOrder] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSubmitting = false
    @Published var errorMessage: String?
    @Published private(set) var hasLoaded = false
    let client: APIClient
    init(client: APIClient = APIClient()) { self.client = client }
    func load() async {
        guard !isLoading else { return }
        isLoading = true; defer { isLoading = false }
        do {
            let loaded: [LabOrder] = try await client.execute(endpoint: LabListEndpoint())
            orders = loaded; hasLoaded = true; errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
    func change(_ order: LabOrder, action: String, data: [String: String] = [:], released: Bool = false) async -> Bool {
        guard !isSubmitting, let version = order.__v else { return false }
        isSubmitting = true; defer { isSubmitting = false }
        do {
            let _: EmptyResponse = try await client.execute(endpoint: LabActionEndpoint(orderId: order.id, action: action, version: version, data: data, released: released))
            await load(); return true
        } catch {
            let message = error.localizedDescription
            await load(); errorMessage = "\(message) Review the current result before retrying."
            return false
        }
    }
}
struct LabWorkbenchView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var model = LabWorkbenchViewModel()
    @State private var editing: LabOrder?
    @State private var pending: LabOrder?
    @State private var action = ""
    var body: some View {
        NavigationStack {
            List {
                if let error = model.errorMessage { StitchErrorState(message: error) { Task { await model.load() } } }
                if model.isLoading && !model.hasLoaded { ProgressView("Loading laboratory requests…") }
                if model.hasLoaded && model.orders.isEmpty && model.errorMessage == nil { Text("No laboratory requests in your workspace.") }
                ForEach(model.orders) { order in
                    Section {
                        LabResultSummary(order: order)
                        if appState.role == "NURSE" {
                            if order.status == "ORDERED" { Button("Confirm sample collection") { pending = order; action = "collect" } }
                            if order.status == "COLLECTED" { Button("Start processing") { pending = order; action = "process" } }
                            if ["PROCESSING", "AVAILABLE", "REVIEWED"].contains(order.status) { Button(order.result == nil ? "Enter verified result" : "Amend verified result") { editing = order } }
                        }
                        if appState.role == "DOCTOR" && order.status == "AVAILABLE" { Button("Acknowledge result review") { pending = order; action = "review" } }
                    }.disabled(model.isSubmitting)
                }
            }.navigationTitle("Laboratory")
            .task(id: scenePhase) { if scenePhase == .active { await model.load() } }
            .refreshable { await model.load() }
            .sheet(item: $editing) { LabResultEntryView(model: model, order: $0) }
            .confirmationDialog("Confirm laboratory action", isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }), presenting: pending) { order in
                Button("Confirm") { Task { _ = await model.change(order, action: action); pending = nil } }
                Button("Cancel", role: .cancel) { pending = nil }
            } message: { order in Text("\(order.patient_name ?? "Patient") · MRN \(order.mrn ?? "Unavailable")\n\(order.name ?? order.test_id) · Visit \(order.encounter_id)\nConfirm the patient, test and current status.") }
        }
    }
}
struct LabResultSummary: View {
    let order: LabOrder
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(order.patient_name ?? "Patient").font(.headline)
            Text("MRN \(order.mrn ?? "Unavailable") · DOB \(order.dob ?? "Unavailable")").font(.caption)
            Text("\(order.name ?? order.test_id) · \(order.status)")
            Text("Visit \(order.encounter_id) · Ordered \(ISODate.display(order.ordered_at))").font(.caption)
            if let result = order.result {
                Text("\(result.value) \(result.unit) · \(result.flag)").font(.headline)
                Text("Reference: \(result.reference_range)")
                Text("Version \(result.version) · Verified by \(result.verified_name ?? "Unavailable") · \(ISODate.display(result.resulted_at))").font(.caption)
                Text(result.released ? "Released to patient" : "Awaiting release").font(.caption)
                if let at = result.reviewed_at { Text("Reviewed \(ISODate.display(at))").font(.caption) }
            }
        }
    }
}
private struct LabResultEntryView: View {
    @ObservedObject var model: LabWorkbenchViewModel
    let order: LabOrder
    @Environment(\.dismiss) private var dismiss
    @State private var value = ""
    @State private var unit = ""
    @State private var referenceRange = ""
    @State private var flag = ""
    @State private var reason = ""
    @State private var verified = false
    @State private var released = false
    @State private var confirming = false
    var body: some View {
        NavigationStack {
            Form {
                LabResultSummary(order: order)
                if let error = model.errorMessage { Text(error).foregroundStyle(.red) }
                TextField("Result value", text: $value)
                TextField("Unit", text: $unit)
                TextField("Reference range from verified report", text: $referenceRange)
                Picker("Report flag", selection: $flag) { Text("Choose report flag").tag("");ForEach(["NORMAL", "HIGH", "LOW", "CRITICAL"], id: \.self) { Text($0) } }
                TextField("Source / amendment reason", text: $reason, axis: .vertical)
                Toggle("I verified the source report and patient identifiers", isOn: $verified)
                Toggle("Release verified result to patient", isOn: $released)
                Text("Copy the authorised laboratory report. A critical result must follow the hospital's escalation procedure.").font(.caption)
            }.navigationTitle(order.result == nil ? "Verified result" : "Amend result")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.disabled(model.isSubmitting) }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { confirming = true }.disabled(model.isSubmitting || !verified || flag.isEmpty || value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || referenceRange.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
            }
            .task { unit = order.result?.unit ?? order.unit ?? ""; value = order.result?.value ?? ""; referenceRange = order.result?.reference_range ?? order.reference_range ?? ""; flag = order.result?.flag ?? "" }
            .interactiveDismissDisabled(model.isSubmitting || !value.isEmpty || !reason.isEmpty)
            .confirmationDialog("Save this verified result?", isPresented: $confirming, titleVisibility: .visible) {
                Button(released ? "Save and release to patient" : "Save for staff review") { Task {
                    if await model.change(order, action: "result", data: ["value": value, "unit": unit, "reference_range": referenceRange, "flag": flag, "reason": reason], released: released) { dismiss() }
                } }
                Button("Keep editing", role: .cancel) {}
            } message: { Text("\(order.patient_name ?? "Patient") · \(order.mrn ?? "MRN unavailable")\n\(order.name ?? order.test_id): \(value) \(unit) · \(flag)") }
        }
    }
}
