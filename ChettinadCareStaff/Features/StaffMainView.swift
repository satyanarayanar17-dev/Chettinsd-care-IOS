import SwiftUI
import ChettinadCore

struct StaffMainView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        SideTabsView(selectedTab: appState.role == "ADMIN" ? "Overview" : "Live queue")
    }
}
