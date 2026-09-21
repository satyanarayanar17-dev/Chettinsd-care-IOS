import SwiftUI
import ChettinadCore

struct DoctorQueueView: View {
    @State private var queue: [QueueEntry] = []
    let apiClient = APIClient()
    
    var body: some View {
        NavigationView {
            List(queue, id: \.id) { entry in
                Text("Patient in queue: \(entry.patient_name) (\(entry.status))")
            }
            .navigationTitle("Doctor Queue")
            .task {
                await loadQueue()
            }
        }
    }
    
    func loadQueue() async {
        do {
            let fetchedQueue: [QueueEntry] = try await apiClient.execute(endpoint: QueueEndpoint())
            DispatchQueue.main.async {
                self.queue = fetchedQueue
            }
        } catch {
            print("Failed to load queue: \(error)")
        }
    }
}

struct NurseTriageView: View {
    @State private var queue: [QueueEntry] = []
    let apiClient = APIClient()
    
    var body: some View {
        NavigationView {
            List(queue, id: \.id) { p in
                Text("To Triage: \(p.patient_name)")
            }
            .navigationTitle("Nurse Triage")
            .task {
                await loadQueue()
            }
        }
    }
    
    func loadQueue() async {
        do {
            let fetchedQueue: [QueueEntry] = try await apiClient.execute(endpoint: QueueEndpoint())
            DispatchQueue.main.async {
                self.queue = fetchedQueue.filter { $0.status == "WAITING" || $0.status == "TRIAGE" }
            }
        } catch {
            print("Failed to load queue: \(error)")
        }
    }
}

struct AdminStaffListView: View {
    var body: some View {
        NavigationView {
            Text("Admin Staff Management")
                .navigationTitle("Staff List")
        }
    }
}
