import SwiftUI

public struct AppHeader: View {
    public let title: String
    @State private var showingNotifications = false
    
    public init(title: String) {
        self.title = title
    }
    
    public var body: some View {
        HStack {
            OfficialLogoSlot()
            
            Text(title)
                .textStyle(Typography.titleMedium, color: .chettinadPrimary)
            
            Spacer()
            
            Button(action: { showingNotifications = true }) {
                Image(systemName: "bell.fill")
                    .foregroundColor(.chettinadSecondary)
                    .font(.system(size: 20))
            }
            .sheet(isPresented: $showingNotifications) {
                NotificationsSheet()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.surfaceContainerLowest)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}
import SwiftUI

public class NotificationsViewModel: ObservableObject {
    @Published public var notifications: [OPDNotification] = []
    @Published public var isLoading = false
    private let apiClient = APIClient()
    
    public init() {}
    
    @MainActor
    public func fetch() async {
        isLoading = true
        do {
            notifications = try await apiClient.execute(endpoint: NotificationsEndpoint())
        } catch {
            print("Notifications fetch error: \(error)")
        }
        isLoading = false
    }
    
    @MainActor
    public func markRead() async {
        do {
            struct NotificationsEmptyResponse: Codable {}
            let _ : NotificationsEmptyResponse = try await apiClient.execute(endpoint: MarkNotificationsReadEndpoint())
            await fetch()
        } catch {
            print("Failed to mark read: \(error)")
        }
    }
}

public struct NotificationsSheet: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var viewModel = NotificationsViewModel()
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            List {
                if viewModel.isLoading && viewModel.notifications.isEmpty {
                    ProgressView().frame(maxWidth: .infinity)
                } else if viewModel.notifications.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bell.slash")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No Notifications")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                } else {
                    ForEach(viewModel.notifications) { note in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.code.replacingOccurrences(of: "_", with: " ").capitalized)
                                .font(.headline)
                                .foregroundColor(note.read_at == nil ? .primary : .secondary)
                            Text(ISODate.display(note.created_at, dateStyle: .medium, timeStyle: .short))
                                .font(.caption)
                                .foregroundColor(.secondary)
                            if let token = note.context.token {
                                Text("Token: \(token)").font(.caption).bold()
                            }
                        }
                        .padding(.vertical, 4)
                        .opacity(note.read_at == nil ? 1.0 : 0.6)
                    }
                }
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if viewModel.notifications.contains(where: { $0.read_at == nil }) {
                        Button("Mark all read") {
                            Task { await viewModel.markRead() }
                        }
                    }
                }
            }
            .task {
                await viewModel.fetch()
            }
            .refreshable {
                await viewModel.fetch()
            }
        }
    }
}
