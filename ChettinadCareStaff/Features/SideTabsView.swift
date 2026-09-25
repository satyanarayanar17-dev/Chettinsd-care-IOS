import SwiftUI
import ChettinadCore

struct SideTabsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab: String? = "Overview"

    private var destinations: [(String, String)] {
        switch appState.role {
        case "ADMIN": return [("Overview", "chart.bar"), ("Appointments", "calendar"), ("Doctor schedules", "clock"), ("Administration", "gearshape"), ("Audit trail", "doc.text.magnifyingglass"), ("My Availability", "clock"), ("My profile & sessions", "person.crop.circle")]
        case "DOCTOR": return [("Overview", "chart.bar"), ("Live queue", "person.3.sequence"), ("Appointments", "calendar"), ("My Availability", "clock"), ("My profile & sessions", "person.crop.circle")]
        case "NURSE": return [("Live queue", "person.3.sequence"), ("Appointments", "calendar"), ("My Availability", "clock"), ("My profile & sessions", "person.crop.circle")]
        default: return [("Overview", "chart.bar")]
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedTab) {
                Section("Chettinad Care") {
                    ForEach(destinations, id: \.0) { destination in NavigationLink(value: destination.0) { Label(destination.0, systemImage: destination.1) } }
                }
            }
            .navigationTitle("Connected OPD")
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    Button("Logout", role: .destructive) {
                        appState.logout()
                    }
                }
            }
        } detail: {
            // Main content depending on selection
            if selectedTab == "Overview" || selectedTab == "Administration" {
                if appState.role == "ADMIN" {
                    AdminTabView()
                } else {
                    Text("Overview & Administration requires Admin access")
                }
            } else if selectedTab == "Live queue" {
                if appState.role == "DOCTOR" {
                    DoctorQueueView()
                } else if appState.role == "NURSE" {
                    NurseTriageView()
                } else {
                    Text("Queue requires clinical access")
                }
            } else {
                VStack(spacing: 12) { Image(systemName: "building.2").font(.largeTitle).foregroundColor(.secondary); Text(selectedTab ?? "Chettinad Care").font(.title2); Text("Obstetrics & Gynaecology pilot data will appear here when available.").foregroundColor(.secondary) }.padding()
            }
        }
        .onAppear { if appState.role == "NURSE" { selectedTab = "Live queue" } }
    }
}
