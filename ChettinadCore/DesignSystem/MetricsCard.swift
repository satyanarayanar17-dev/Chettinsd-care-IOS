import SwiftUI

public struct MetricsCard: View {
    public let title: String
    public let value: String
    public let iconName: String
    public let trend: String?
    
    public init(title: String, value: String, iconName: String, trend: String? = nil) {
        self.title = title
        self.value = value
        self.iconName = iconName
        self.trend = trend
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.chettinadPrimary.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: iconName)
                        .foregroundColor(.chettinadPrimary)
                        .font(.system(size: 20))
                }
                
                Spacer()
                
                if let trend = trend {
                    Text(trend)
                        .textStyle(Typography.labelSmall, color: .chettinadSuccess)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.chettinadSuccessContainer)
                        .cornerRadius(12)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .textStyle(Typography.headlineSmall, color: .chettinadTextPrimary)
                
                Text(title)
                    .textStyle(Typography.bodySmall, color: .chettinadTextSecondary)
            }
        }
        .padding(16)
        .background(Color.surfaceContainerLowest)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
