import SwiftUI
import ChettinadCore

struct ConsultationFollowUpSection: View {
    @ObservedObject var model: DoctorConsultationViewModel
    @State private var directory: OPDDirectory?
    @State private var doctorId = ""
    @State private var date = Date().addingTimeInterval(86400)
    @State private var slots: [AppointmentSlot] = []
    @State private var reason = ""
    @State private var error: String?
    @State private var loading = false
    private var searchKey: String { doctorId + hospitalDay(date) }
    var body: some View {
        Section("Follow-up appointment") {
            if let follow = model.followUp {
                Text("\(directory?.doctors.first { $0.id == follow.doctor_id }?.name ?? follow.doctor_id) · \(ISODate.display(follow.scheduled_at))")
                Text(follow.reason)
                Text(model.isFinalized ? "The linked appointment is managed from Appointments." : "This appointment is requested when the consultation is signed.").font(.caption)
                if !model.isFinalized { Button("Remove follow-up request", role: .destructive) { model.followUp = nil } }
            } else if !model.isFinalized {
                Picker("Doctor", selection: $doctorId) {
                    Text("Choose doctor").tag("")
                    ForEach((directory?.doctors ?? []).filter { $0.id == model.recordBundle?.encounters.first { $0.id == model.encounterId }?.assigned_doctor_id }) { Text($0.name).tag($0.id) }
                }
                DatePicker("Date (hospital time)", selection: $date, in: Date()..., displayedComponents: .date)
                TextField("Reason for follow-up", text: $reason)
                if loading { ProgressView("Loading available times…") }
                if let error { Text(error).foregroundStyle(.red) }
                if !doctorId.isEmpty && !loading && slots.isEmpty && error == nil { Text("No available times for this date.").font(.caption) }
                ForEach(slots) { slot in
                    Button(ISODate.display(slot.scheduled_at)) {
                        model.followUp = FollowUpRequest(doctor_id: doctorId, scheduled_at: slot.scheduled_at, reason: reason.trimmingCharacters(in: .whitespacesAndNewlines))
                    }.disabled(reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            } else { Text("No follow-up appointment was requested.") }
        }
        .task {
            do { directory = try await model.apiClient.execute(endpoint: DirectoryEndpoint()) }
            catch { self.error = error.localizedDescription }
        }
        .task(id: searchKey) {
            slots = []; guard !doctorId.isEmpty else { return }
            loading = true; defer { loading = false }
            do {
                let loaded: [AppointmentSlot] = try await model.apiClient.execute(endpoint: AppointmentSlotsEndpoint(doctorId: doctorId, date: hospitalDay(date)))
                guard !Task.isCancelled else { return }; slots = loaded; error = nil
            } catch { if !Task.isCancelled { self.error = error.localizedDescription } }
        }
    }
    private func hospitalDay(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .gregorian); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(identifier: "Asia/Kolkata"); formatter.dateFormat = "yyyy-MM-dd"; return formatter.string(from: date)
    }
}

struct ConsultationComparison: View {
    let data: ConsultationData
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Complaint: \(data.complaint ?? "")")
            Text("History: \(data.history ?? "")")
            Text("Previous history: \(data.previous_history ?? "")")
            Text("Examination: \(data.examination ?? "")")
            Text("Assessment: \(data.assessment ?? "")")
            Text("Diagnoses: \(data.diagnosis_ids.joined(separator: ", "))")
            Text("Treatment: \(data.treatment ?? "")")
            Text("Advice: \(data.advice ?? "")")
            ForEach(Array(data.medications.enumerated()), id: \.offset) { _, med in
                Text("\(med.drug_id): \(med.dose) · \(med.frequency) · \(med.duration) · \(med.instructions ?? "")")
            }
            if let follow = data.follow_up { Text("Follow-up: \(follow.doctor_id) · \(follow.scheduled_at) · \(follow.reason)") }
        }
    }
}
