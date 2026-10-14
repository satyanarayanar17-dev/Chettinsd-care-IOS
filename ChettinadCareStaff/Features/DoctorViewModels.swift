import SwiftUI
import ChettinadCore
import CryptoKit

// MARK: - Response DTOs

struct EncounterMutationResponse: Codable {
    let encounter_id: String?
    let __v: Int?
    let phase: String?
}

struct NoteResponse: Codable {
    let id: String?
    let status: String?
    let __v: Int?
}

// MARK: - Endpoints

struct StartConsultEndpoint: APIEndpoint {
    let encounterId: String
    let v: Int
    var path: String { "/api/v1/opd/encounters/\(encounterId)/start" }
    var method: HTTPMethod { .post }
    var body: Data? { try? JSONSerialization.data(withJSONObject: ["__v": v]) }
}

struct CompleteConsultEndpoint: APIEndpoint {
    let encounterId: String
    let v: Int
    let data: ConsultationData
    var patientVersion: Int? = nil
    var path: String { "/api/v1/opd/encounters/\(encounterId)/complete" }
    var method: HTTPMethod { .post }
    var body: Data? {
        let payload = CompletePayload(patient__v:patientVersion,__v: v, data: data)
        return try? JSONEncoder().encode(payload)
    }
}

struct SaveConsultationEndpoint: APIEndpoint {
    let encounterId: String
    let v: Int
    let data: ConsultationData
    var path: String { "/api/v1/opd/encounters/\(encounterId)/consultation" }
    var method: HTTPMethod { .put }
    var body: Data? { try? JSONEncoder().encode(CompletePayload(__v: v, data: data)) }
}

struct AmendConsultEndpoint: APIEndpoint {
    typealias Response = EncounterMutationResponse
    let encounterId: String
    let v: Int
    let data: ConsultationData
    let reason: String
    var patientVersion: Int? = nil
    var path: String { "/api/v1/opd/encounters/\(encounterId)/amend" }
    var method: HTTPMethod { .post }
    var body: Data? {
        struct AmendPayload: Codable {
            let __v: Int
            let data: ConsultationData
            let reason: String
            let patient__v: Int?
        }
        return try? JSONEncoder().encode(AmendPayload(__v: v, data: data, reason: reason,patient__v:patientVersion))
    }
}


struct CompletePayload: Codable {
    var patient__v: Int? = nil
    let __v: Int
    let data: ConsultationData
}

struct ConsultationData: Codable, Equatable, Sendable {
    let complaint: String?
    let history: String?
    let previous_history: String?
    let examination: String?
    let assessment: String?
    let diagnosis_ids: [String]
    let treatment: String?
    let advice: String?
    let medications: [PrescriptionDrug]
    let follow_up: FollowUpRequest?

    init(complaint: String?, history: String?, previous_history: String?, examination: String?, assessment: String?, diagnosis_ids: [String], treatment: String?, advice: String?, medications: [PrescriptionDrug], follow_up: FollowUpRequest? = nil) {
        self.complaint = complaint; self.history = history; self.previous_history = previous_history
        self.examination = examination; self.assessment = assessment; self.diagnosis_ids = diagnosis_ids
        self.treatment = treatment; self.advice = advice; self.medications = medications; self.follow_up = follow_up
    }
}

struct PrescriptionDrug: Codable, Equatable, Sendable {
    let drug_id: String
    let dose: String
    let frequency: String
    let duration: String
    let instructions: String?
}

struct PatientRecordEndpoint: APIEndpoint {
    let patientId: String
    var path: String { "/api/v1/opd/patients/\(patientId)/record" }
    var method: HTTPMethod { .get }
}

// MARK: - Queue ViewModel

@MainActor
class StaffQueueViewModel: ObservableObject {
    @Published var queue: [QueueEntry] = []
    @Published var metrics: AdminMetricsResponse?
    @Published var isLoading = false
    @Published var hasLoaded = false
    @Published var errorMessage: String?

    let role: String
    let apiClient: APIClient

    init(role: String, apiClient: APIClient = APIClient()) {
        self.role = role
        self.apiClient = apiClient
    }

    static func includes(status: String, role: String) -> Bool {
        switch role {
        case "DOCTOR": return ["WAITING_DOCTOR", "DOCTOR_READY", "CONSULTATION"].contains(status)
        case "NURSE": return ["WAITING", "TRIAGE"].contains(status)
        default: return false
        }
    }

    func fetchQueue() async {
        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        do {
            async let queueRequest: [QueueEntry] = apiClient.execute(endpoint: QueueEndpoint())
            async let metricsRequest: AdminMetricsResponse = apiClient.execute(endpoint: AdminMetricsEndpoint())
            let (queue, metrics) = try await (queueRequest, metricsRequest)
            guard !Task.isCancelled else { return }
            self.queue = queue.filter { Self.includes(status: $0.status, role: role) }
            self.metrics = metrics
            hasLoaded = true
        } catch {
            guard !Task.isCancelled, (error as NSError).code != NSURLErrorCancelled else { return }
            errorMessage = hasLoaded
                ? "We couldn't update the queue. Previously loaded details are shown. Please retry."
                : "We couldn't load the queue. Please retry."
        }
    }
}

@MainActor
final class DoctorQueueViewModel: StaffQueueViewModel {
    init(apiClient: APIClient = APIClient()) { super.init(role: "DOCTOR", apiClient: apiClient) }
}

// MARK: - Consultation ViewModel

@MainActor
class DoctorConsultationViewModel: ObservableObject {
    @Published var recordBundle: RecordBundle?
    @Published var isLoading = true
    @Published var errorMessage: String?
    @Published var currentVersion: Int
    @Published var noteVersion = 0
    let encounterId: String?
    let patientId: String
    @Published var noteComplaint = ""
    @Published var noteHistory = ""
    @Published var notePreviousHistory = ""
    @Published var noteExamination = ""
    @Published var noteAssessment = ""
    @Published var noteTreatment = ""
    @Published var noteAdvice = ""
    @Published var selectedDiagnoses: Set<String> = []
    @Published var medications: [PrescriptionDrug] = []
    @Published var followUp: FollowUpRequest?
    @Published var catalogues: CataloguesResponse?
    @Published var labOrdersInFlight: Set<String> = []
    @Published var isSubmitting = false
    @Published var consultationCompleted = false
    @Published var amendReason = ""
    @Published var lastSavedAt: String?
    @Published var recoveryMessage: String?
    @Published var conflictingSavedDraft: ConsultationData?
    @Published var conflictingNoteVersion: Int?

    let apiClient: APIClient
    private var authenticatedActorId: String?
    private let persistLocalDrafts: Bool
    private let draftStore: ProtectedClinicalDraftStore
    private var savedDraft: ConsultationData?
    private var loadedDraft = false
    private var editorActive = false
    private var pendingAutosave: Task<Void, Never>?

    init(encounterId: String?, patientId: String, initialVersion: Int, apiClient: APIClient = APIClient(), authenticatedActorId: String? = nil, persistLocalDrafts: Bool = true, draftDirectory: URL? = nil) {
        self.encounterId = encounterId; self.patientId = patientId; self.currentVersion = initialVersion
        self.apiClient = apiClient; self.authenticatedActorId = authenticatedActorId; self.persistLocalDrafts = persistLocalDrafts
        self.draftStore = draftDirectory.map { ProtectedClinicalDraftStore(directory:$0) } ?? .shared
    }

    var orderedTestIds: Set<String> { Set(recordBundle?.labs.filter { $0.encounter_id == encounterId }.map(\.test_id) ?? []) }
    var isFinalized: Bool { recordBundle?.encounters.first { $0.id == encounterId }?.discharged == true }
    var ownsEncounter: Bool {
        guard let actor = authenticatedActorId else { return false }
        return recordBundle?.encounters.first { $0.id == encounterId }?.assigned_doctor_id == actor
    }
    var draftPayload: ConsultationData {
        ConsultationData(complaint: clean(noteComplaint), history: clean(noteHistory), previous_history: clean(notePreviousHistory),
            examination: clean(noteExamination), assessment: clean(noteAssessment), diagnosis_ids: selectedDiagnoses.sorted(),
            treatment: clean(noteTreatment), advice: clean(noteAdvice), medications: medications.map {
                PrescriptionDrug(drug_id:$0.drug_id,dose:$0.dose.trimmingCharacters(in:.whitespacesAndNewlines),frequency:$0.frequency.trimmingCharacters(in:.whitespacesAndNewlines),duration:$0.duration.trimmingCharacters(in:.whitespacesAndNewlines),instructions:clean($0.instructions))
            }, follow_up: followUp)
    }
    var hasUnsavedChanges: Bool {
        if let savedDraft { return draftPayload != savedDraft }
        let data = draftPayload
        return [data.complaint,data.history,data.previous_history,data.examination,data.assessment,data.treatment,data.advice].contains { $0 != nil }
            || !data.diagnosis_ids.isEmpty || !data.medications.isEmpty || data.follow_up != nil
    }
    var canFinalize: Bool {
        let data = draftPayload
        return ownsEncounter && !isSubmitting && data.history != nil && data.examination != nil && data.assessment != nil
            && data.advice != nil && !data.diagnosis_ids.isEmpty && conflictingSavedDraft == nil
    }

    private func clean(_ text: String?) -> String? {
        let value = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? nil : value
    }
    private func payload(from note: Note?) -> ConsultationData {
        let data = note?.draft_content
        return ConsultationData(complaint: clean(data?.complaint), history: clean(data?.history), previous_history: clean(data?.previous_history),
            examination: clean(data?.examination), assessment: clean(data?.assessment),
            diagnosis_ids: (data?.diagnosis_ids ?? data?.diagnoses?.map(\.id) ?? []).sorted(),
            treatment: clean(data?.treatment), advice: clean(data?.advice),
            medications: data?.medications?.map { PrescriptionDrug(drug_id:$0.drug_id,dose:$0.dose,frequency:$0.frequency,duration:$0.duration,instructions:clean($0.instructions)) } ?? [],
            follow_up: data?.follow_up)
    }
    private func apply(_ data: ConsultationData) {
        noteComplaint = data.complaint ?? ""; noteHistory = data.history ?? ""; notePreviousHistory = data.previous_history ?? ""
        noteExamination = data.examination ?? ""; noteAssessment = data.assessment ?? ""; noteTreatment = data.treatment ?? ""
        noteAdvice = data.advice ?? ""; selectedDiagnoses = Set(data.diagnosis_ids); medications = data.medications; followUp = data.follow_up
    }

    func fetchCatalogues() async {
        do { catalogues = try await apiClient.execute(endpoint: CataloguesEndpoint()) }
        catch { errorMessage = "We couldn't load the clinical catalogue. Please retry." }
    }
    func fetchPatientDossier() async {
        isLoading = true
        defer { isLoading = false }
        do {
            if authenticatedActorId == nil { authenticatedActorId = await apiClient.sessionManager.getSession()?.userId }
            let bundle: RecordBundle = try await apiClient.execute(endpoint: PatientRecordEndpoint(patientId: patientId))
            guard !Task.isCancelled else { return }
            guard bundle.patient.id == patientId,
                  encounterId == nil || bundle.encounters.contains(where: { $0.id == encounterId && $0.patient_id == patientId }) else { throw APIError.invalidResponse }
            recordBundle = bundle
            let note = bundle.notes.first { $0.encounter_id == encounterId }
            let serverVersion = note?.__v ?? 0
            let serverDraft = payload(from: note)
            if !loadedDraft || !hasUnsavedChanges {
                apply(serverDraft); savedDraft = serverDraft; noteVersion = serverVersion
                lastSavedAt = note?.updated_at ?? note?.created_at
                if !loadedDraft { await recoverLocalDraft(serverDraft:serverDraft,version:serverVersion) }
                loadedDraft = true
            } else if serverVersion != noteVersion {
                conflictingSavedDraft = serverDraft; conflictingNoteVersion = serverVersion
            }
        } catch {
            if !Task.isCancelled { errorMessage = "We couldn't update this record. Your entered note is retained. Please retry." }
        }
    }
    func startConsultation() async -> Bool {
        guard let encounterId, !isSubmitting else { return false }
        isSubmitting = true; errorMessage = nil
        defer { isSubmitting = false }
        do {
            let queue: [QueueEntry] = try await apiClient.execute(endpoint: QueueEndpoint())
            guard let entry = queue.first(where: { $0.encounter_id == encounterId }) else { throw APIError.invalidResponse }
            currentVersion = entry.__v
            if entry.status != "CONSULTATION" {
                let _: EncounterMutationResponse = try await apiClient.execute(endpoint: StartConsultEndpoint(encounterId: encounterId,v:currentVersion))
            }
            await fetchPatientDossier()
            return recordBundle != nil && !isFinalized
        } catch { handle(error); return false }
    }

    func beginEditing() { editorActive = true; if hasUnsavedChanges { draftChanged() } }
    func stopEditing() {
        editorActive = false; pendingAutosave?.cancel(); pendingAutosave = nil
        Task { await persistLocalDraft() }
    }
    func draftChanged() {
        guard editorActive, !isFinalized else { return }
        Task { await persistLocalDraft() }
        pendingAutosave?.cancel()
        guard !isSubmitting, hasUnsavedChanges, conflictingSavedDraft == nil else { return }
        pendingAutosave = Task { [weak self] in
            do { try await Task.sleep(for:.seconds(3)) } catch { return }
            guard let self, self.editorActive else { return }
            self.pendingAutosave = nil
            _ = await self.saveDraft()
        }
    }

    func saveDraft() async -> Bool {
        guard let encounterId, ownsEncounter, !isSubmitting, !isFinalized, conflictingSavedDraft == nil else { return false }
        pendingAutosave?.cancel(); pendingAutosave = nil
        let data = draftPayload
        let expectedVersion = noteVersion
        isSubmitting = true; errorMessage = nil
        var savedSuccessfully = false
        defer {
            isSubmitting = false
            if savedSuccessfully && editorActive && hasUnsavedChanges { draftChanged() }
        }
        await persistLocalDraft()
        do {
            let response: NoteResponse = try await apiClient.execute(endpoint: SaveConsultationEndpoint(encounterId:encounterId,v:expectedVersion,data:data))
            noteVersion = response.__v ?? expectedVersion + 1; savedDraft = data
            lastSavedAt = ISO8601DateFormatter().string(from:Date()); recoveryMessage = nil
            await persistLocalDraft()
            savedSuccessfully = true
            return true
        } catch {
            if await reconcile(data:data,expectedVersion:expectedVersion,finalized:false) { savedSuccessfully = true; return true }
            handle(error); return false
        }
    }

    func completeConsultation() async -> Bool { await submitFinal(amend:false) }
    func amendConsultation() async -> Bool { await submitFinal(amend:true) }
    private func submitFinal(amend: Bool) async -> Bool {
        guard let encounterId, canFinalize else { return false }
        if amend && amendReason.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty {
            errorMessage = "Enter a reason for the amendment."; return false
        }
        pendingAutosave?.cancel(); pendingAutosave = nil
        let data = draftPayload, expectedVersion = noteVersion
        isSubmitting = true; errorMessage = nil
        defer { isSubmitting = false }
        await persistLocalDraft()
        do {
            if amend {
                let _: EncounterMutationResponse = try await apiClient.execute(endpoint:AmendConsultEndpoint(encounterId:encounterId,v:expectedVersion,data:data,reason:amendReason,patientVersion:recordBundle?.patient.__v))
            } else {
                let _: NoteResponse = try await apiClient.execute(endpoint:CompleteConsultEndpoint(encounterId:encounterId,v:expectedVersion,data:data,patientVersion:recordBundle?.patient.__v))
            }
            consultationCompleted = true; savedDraft = data
            await clearLocalDraft(); return true
        } catch {
            if await reconcile(data:data,expectedVersion:expectedVersion,finalized:true) { return true }
            handle(error); return false
        }
    }
    private func reconcile(data: ConsultationData, expectedVersion: Int, finalized: Bool) async -> Bool {
        // A lost response must be resolved by reading the authoritative record, not by signing twice.
        guard let encounterId else { return false }
        do {
            let bundle: RecordBundle = try await apiClient.execute(endpoint:PatientRecordEndpoint(patientId:patientId))
            guard let note = bundle.notes.first(where: { $0.encounter_id == encounterId }) else { return false }
            recordBundle = bundle
            let latest = payload(from:note), version = note.__v ?? 0
            let own = note.author_id == authenticatedActorId
            if own && version == expectedVersion + 1 && latest == data && (finalized ? note.status == "FINALIZED" : note.status == "DRAFT") {
                noteVersion = version; savedDraft = data; lastSavedAt = note.updated_at ?? note.created_at
                if finalized { consultationCompleted = true; await clearLocalDraft() }
                return true
            }
            if version != expectedVersion { conflictingSavedDraft = latest; conflictingNoteVersion = version }
        } catch { /* The local draft remains protected until a later verified recovery. */ }
        return false
    }
    func useLatestSavedDraft() {
        guard let latest = conflictingSavedDraft, let version = conflictingNoteVersion else { return }
        apply(latest); savedDraft = latest; noteVersion = version
        conflictingSavedDraft = nil; conflictingNoteVersion = nil; errorMessage = nil
        Task { await persistLocalDraft() }
    }
    func keepMyDraftAfterReview() {
        guard let latest = conflictingSavedDraft, let version = conflictingNoteVersion else { return }
        savedDraft = latest; noteVersion = version; conflictingSavedDraft = nil; conflictingNoteVersion = nil; errorMessage = nil
        draftChanged()
    }

    func orderLab(testId: String) async {
        guard let encounterId, !orderedTestIds.contains(testId), !labOrdersInFlight.contains(testId) else { return }
        labOrdersInFlight.insert(testId); defer { labOrdersInFlight.remove(testId) }
        do {
            let _: NoteResponse = try await apiClient.execute(endpoint:OrderLabEndpoint(encounterId:encounterId,testId:testId))
            await fetchPatientDossier()
        } catch { handle(error) }
    }
    private func handle(_ error: Error) {
        if let apiError = error as? APIError, case .apiError(_,let response) = apiError {
            errorMessage = response.error.code == "STALE_STATE"
                ? "A newer saved note is available. Review the saved version before continuing. Your entered text is retained."
                : response.error.message
        } else { errorMessage = "We couldn't confirm this action. Your entered note is retained. Reconnect and retry." }
    }

    private func localIdentity() async -> (key:String,actor:String)? {
        guard persistLocalDrafts, let encounterId else { return nil }
        guard let actor = authenticatedActorId else { return nil }
        let key = SHA256.hash(data:Data("\(actor)|\(patientId)|\(encounterId)".utf8)).map { String(format:"%02x",$0) }.joined()
        return (key,actor)
    }
    @discardableResult
    func persistLocalDraft() async -> Bool {
        if !persistLocalDrafts { return true }
        guard let encounterId, let identity = await localIdentity() else { return false }
        if consultationCompleted || !hasUnsavedChanges { await draftStore.remove(identity.key); return true }
        let stored = ProtectedClinicalDraft(actor:identity.actor,patient:patientId,encounter:encounterId,noteVersion:noteVersion,data:draftPayload)
        do { try await draftStore.save(stored,key:identity.key); return true }
        catch { recoveryMessage = "This device couldn't protect a recovery copy. Save the draft before leaving."; return false }
    }
    private func recoverLocalDraft(serverDraft: ConsultationData, version: Int) async {
        guard let identity = await localIdentity(),
              let stored = await draftStore.read(identity.key), stored.actor == identity.actor,
              stored.patient == patientId, stored.encounter == encounterId, stored.data != serverDraft else { return }
        apply(stored.data); noteVersion = stored.noteVersion
        recoveryMessage = "An unfinished draft was restored on this device. Review it before saving."
        if stored.noteVersion != version { conflictingSavedDraft = serverDraft; conflictingNoteVersion = version }
    }
    private func clearLocalDraft() async {
        if let identity = await localIdentity() { await draftStore.remove(identity.key) }
    }
}

private struct ProtectedClinicalDraft: Codable, Sendable {
    let actor: String
    let patient: String
    let encounter: String
    let noteVersion: Int
    let data: ConsultationData
}

private actor ProtectedClinicalDraftStore {
    static let shared = ProtectedClinicalDraftStore()
    private let folder: URL
    init(directory: URL? = nil) {
        folder = directory ?? FileManager.default.urls(for:.applicationSupportDirectory,in:.userDomainMask)[0]
            .appendingPathComponent(Bundle.main.bundleIdentifier ?? "com.chettinadcare.staff",isDirectory:true)
            .appendingPathComponent("ProtectedClinicalDrafts",isDirectory:true)
    }
    func save(_ draft: ProtectedClinicalDraft, key: String) throws {
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
        var excluded = URLResourceValues(); excluded.isExcludedFromBackup = true
        var directory = folder; try directory.setResourceValues(excluded)
        try JSONEncoder().encode(draft).write(to:folder.appendingPathComponent(key+".json"),options:[.atomic,.completeFileProtection])
    }
    func read(_ key: String) -> ProtectedClinicalDraft? {
        guard let data = try? Data(contentsOf:folder.appendingPathComponent(key+".json")) else { return nil }
        return try? JSONDecoder().decode(ProtectedClinicalDraft.self,from:data)
    }
    func remove(_ key: String) { try? FileManager.default.removeItem(at:folder.appendingPathComponent(key+".json")) }
}

struct CataloguesResponse: Codable {
    struct Drug: Codable, Identifiable {
        let id: String
        let name: String
        let strength: String
        let form: String
        let route: String
    }
    struct Diagnosis: Codable, Identifiable {
        let id: String
        let name: String
    }
    struct Test: Codable, Identifiable {
        let id: String
        let name: String
        let code: String
    }
    let drugs: [Drug]
    let diagnoses: [Diagnosis]
    let tests: [Test]
}

struct CataloguesEndpoint: APIEndpoint {
    var path: String { "/api/v1/opd/catalogues" }
    var method: HTTPMethod { .get }
}

struct OrderLabEndpoint: APIEndpoint {
    let encounterId: String
    let testId: String
    var path: String { "/api/v1/opd/encounters/\(encounterId)/labs" }
    var method: HTTPMethod { .post }
    var body: Data? { try? JSONSerialization.data(withJSONObject: ["test_id": testId]) }
}
