import SwiftUI
import ChettinadCore

struct StaffAppointmentMutationEndpoint: APIEndpoint {
    let id: String
    let action: String
    let version: Int
    var scheduledAt: String? = nil
    var path: String { "/api/v1/opd/appointments/\(id)/\(action)" }
    var method: HTTPMethod { .post }
    var body: Data? { var value: [String:Any] = ["__v":version];if let scheduledAt { value["scheduled_at"] = scheduledAt };return try? JSONSerialization.data(withJSONObject:value) }
}
struct ReassignVisitEndpoint: APIEndpoint {
    let encounterId: String
    let doctorId: String
    let version: Int
    let reason: String
    var path: String { "/api/v1/opd/encounters/\(encounterId)/reassign" }
    var method: HTTPMethod { .post }
    var body: Data? { try? JSONSerialization.data(withJSONObject:["__v":version,"doctor_id":doctorId,"reason":reason]) }
}
struct StaffAppointmentActions: View {
    let appointment: Appointment
    let onChanged: () -> Void
    @State private var pending: String?
    @State private var editing: String?
    @State private var saving = false
    @State private var error: String?
    private let client = APIClient()
    var body: some View {
        VStack(alignment:.leading) {
            if let error { Text(error).foregroundStyle(.red) }
            if ["CONFIRMED","PENDING_CONFIRMATION"].contains(appointment.status) {
                Button("Reschedule appointment") { editing = "reschedule" }
                Button("Cancel appointment",role:.destructive) { pending = "cancel" }
                if let ends = appointment.ends_at, (ISODate.parse(ends) ?? .distantFuture) < Date() { Button("Mark did not attend") { pending = "no-show" } }
            }
            if appointment.status == "CHECKED_IN" && ["WAITING","WAITING_DOCTOR","DOCTOR_READY"].contains(appointment.queue_status ?? "") {
                Button("Transfer unstarted visit") { editing = "reassign" }
            }
        }.disabled(saving)
        .sheet(isPresented:Binding(get:{editing != nil},set:{if !$0 { editing = nil }})) {
            AppointmentOperationsSheet(appointment:appointment,action:editing ?? "reschedule",onChanged:onChanged)
        }
        .confirmationDialog("Confirm appointment change",isPresented:Binding(get:{pending != nil},set:{if !$0 { pending = nil }}),titleVisibility:.visible) {
            Button("Confirm change") { let action = pending ?? "";pending = nil;Task { await change(action) } }
            Button("Keep appointment",role:.cancel) { pending = nil }
        } message: { Text("\(appointment.patient_name ?? "Patient") · MRN \(appointment.mrn ?? "Unavailable") · DOB \(appointment.dob ?? "Unavailable")\n\(ISODate.display(appointment.scheduled_at)) · \(appointment.doctor_name ?? "Doctor")") }
    }
    @MainActor private func change(_ action: String) async {
        guard !saving, let version = appointment.__v else { return };saving = true;defer { saving = false }
        do { let _: EmptyResponse = try await client.execute(endpoint:StaffAppointmentMutationEndpoint(id:appointment.id,action:action,version:version));error = nil;onChanged() }
        catch { self.error = error.localizedDescription }
    }
}
private struct AppointmentOperationsSheet: View {
    let appointment: Appointment
    let action: String
    let onChanged: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var directory: OPDDirectory?
    @State private var queue: QueueEntry?
    @State private var doctorId = ""
    @State private var reason = ""
    @State private var selectedTime = ""
    @State private var slots: [AppointmentSlot] = []
    @State private var saving = false
    @State private var loading = true
    @State private var error: String?
    private let client = APIClient()
    var body: some View {
        NavigationStack {
            Form {
                Text(appointment.patient_name ?? "Patient").font(.headline)
                Text("MRN \(appointment.mrn ?? "Unavailable") · DOB \(appointment.dob ?? "Unavailable")")
                if loading { ProgressView("Loading current visit…") }
                if let error { Text(error).foregroundStyle(.red) }
                if action == "reassign" {
                    Text("Confirm the receiving doctor accepts this visit. Transfer is allowed before a consultation note or lab order exists.").font(.caption)
                    Picker("Receiving doctor",selection:$doctorId) {
                        Text("Choose doctor").tag("")
                        ForEach((directory?.doctors ?? []).filter { $0.department == queue?.department_name && $0.id != queue?.doctor_id }) { Text($0.name).tag($0.id) }
                    }
                    TextField("Reason and receiving doctor's acceptance",text:$reason,axis:.vertical)
                } else {
                    DatePicker("Date (hospital time)",selection:$date,in:Date()...,displayedComponents:.date)
                    Picker("Available time",selection:$selectedTime) {
                        Text("Choose time").tag("")
                        ForEach(slots) { Text(ISODate.display($0.scheduled_at)).tag($0.scheduled_at) }
                    }
                }
            }.navigationTitle(action == "reassign" ? "Transfer visit" : "Reschedule")
            .toolbar {
                ToolbarItem(placement:.cancellationAction) { Button("Close") { dismiss() }.disabled(saving) }
                ToolbarItem(placement:.confirmationAction) { Button("Confirm change") { Task { await save() } }.disabled(saving || loading || (action == "reassign" ? doctorId.isEmpty || reason.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || queue == nil : selectedTime.isEmpty)) }
            }
            .task {
                do {
                    if action == "reassign" {
                        directory = try await client.execute(endpoint:DirectoryEndpoint())
                        let entries: [QueueEntry] = try await client.execute(endpoint:QueueEndpoint())
                        queue = entries.first { $0.encounter_id == appointment.encounter_id && $0.patient_id == appointment.patient_id }
                        if queue == nil { throw APIError.invalidResponse }
                    }
                    loading = false
                } catch { self.error = error.localizedDescription;loading = false }
            }
            .task(id:date) {
                guard action == "reschedule", let doctor = appointment.doctor_id else { return }
                selectedTime = "";slots = []
                let formatter = DateFormatter();formatter.calendar=Calendar(identifier:.gregorian);formatter.locale=Locale(identifier:"en_US_POSIX");formatter.timeZone=TimeZone(identifier:"Asia/Kolkata");formatter.dateFormat="yyyy-MM-dd"
                do { let loaded: [AppointmentSlot] = try await client.execute(endpoint:AppointmentSlotsEndpoint(doctorId:doctor,date:formatter.string(from:date)));if !Task.isCancelled { slots=loaded;error=nil } }
                catch { if !Task.isCancelled { self.error=error.localizedDescription } }
            }
            .interactiveDismissDisabled(saving)
        }
    }
    @MainActor private func save() async {
        guard !saving else { return };saving = true;defer { saving = false }
        do {
            if action == "reassign", let queue {
                let _: EmptyResponse = try await client.execute(endpoint:ReassignVisitEndpoint(encounterId:queue.encounter_id,doctorId:doctorId,version:queue.__v,reason:reason))
            } else if let version = appointment.__v {
                let _: EmptyResponse = try await client.execute(endpoint:StaffAppointmentMutationEndpoint(id:appointment.id,action:"reschedule",version:version,scheduledAt:selectedTime))
            } else { throw APIError.invalidResponse }
            onChanged();dismiss()
        } catch { self.error=error.localizedDescription }
    }
}
