import SwiftUI
import ChettinadCore

struct PatientDashboardView: View {
    @State private var dashboardStats = "Loading Dashboard..."
    var body: some View {
        NavigationView {
            Text(dashboardStats)
                .navigationTitle("Dashboard")
        }
    }
}

struct PatientRecordsView: View {
    @State private var recordBundle: RecordBundle?
    let apiClient = APIClient()
    
    var body: some View {
        NavigationView {
            List {
                if let bundle = recordBundle {
                    Section(header: Text("Patient Info")) {
                        Text("Name: \(bundle.patient.name)")
                        Text("MRN: \(bundle.patient.mrn)")
                    }
                    
                    Section(header: Text("Notes")) {
                        ForEach(bundle.notes) { note in
                            Text("Note Status: \(note.status)")
                        }
                    }
                    
                    Section(header: Text("Prescriptions")) {
                        ForEach(bundle.prescriptions) { rx in
                            Text("Prescription: \(rx.status)")
                        }
                    }
                } else {
                    Text("Loading Records...")
                }
            }
            .navigationTitle("Records")
            .task {
                await loadData()
            }
        }
    }
    
    func loadData() async {
        do {
            let session: UserSession = try await apiClient.execute(endpoint: OPDSessionEndpoint())
            guard let patientId = session.patient_id else { return }
            
            struct PatientRecordEndpoint: APIEndpoint {
                let patientId: String
                var path: String { "/api/v1/opd/patients/\(patientId)/record" }
                var method: HTTPMethod { .get }
            }
            let bundle: RecordBundle = try await apiClient.execute(endpoint: PatientRecordEndpoint(patientId: patientId))
            DispatchQueue.main.async {
                self.recordBundle = bundle
            }
        } catch {
            print("Failed to load patient data: \(error)")
        }
    }
}

struct PatientProfileView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Profile")
                Button("Logout", role: .destructive) {
                    appState.logout()
                }
                .padding()
            }
            .navigationTitle("Profile")
        }
    }
}
