import SwiftUI

public struct AppHeader: View {
    public let title: String
    public let onNotificationClick: () -> Void
    
    public init(title: String, onNotificationClick: @escaping () -> Void = {}) {
        self.title = title
        self.onNotificationClick = onNotificationClick
    }
    
    public var body: some View {
        HStack {
            OfficialLogoSlot()
            
            Text(title)
                .textStyle(Typography.titleMedium, color: .chettinadPrimary)
            
            Spacer()
            
            Button(action: onNotificationClick) {
                Image(systemName: "bell.fill")
                    .foregroundColor(.chettinadSecondary)
                    .font(.system(size: 20))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.surfaceContainerLowest)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}
