import SwiftUI

public extension Color {
    // Primary Brand
    static let chettinadPrimary = Color(hex: 0x000666)
    static let chettinadSecondary = Color(hex: 0x4B5563) // Gray 600
    
    // Backgrounds & Surfaces
    static let chettinadBackground = Color(hex: 0xF9FAFB) // Gray 50
    static let surfaceContainerLowest = Color.white
    static let surfaceContainerLow = Color(hex: 0xF3F4F6) // Gray 100
    static let surfaceContainerHigh = Color(hex: 0xE5E7EB) // Gray 200
    
    // Status & Feedback
    static let chettinadError = Color(hex: 0xDC2626) // Red 600
    static let chettinadErrorContainer = Color(hex: 0xFEE2E2) // Red 100
    static let onChettinadErrorContainer = Color(hex: 0x991B1B) // Red 800
    
    static let chettinadSuccess = Color(hex: 0x16A34A) // Green 600
    static let chettinadSuccessContainer = Color(hex: 0xDCFCE7) // Green 100
    static let onChettinadSuccessContainer = Color(hex: 0x166534) // Green 800
    
    static let chettinadWarning = Color(hex: 0xD97706) // Amber 600
    static let chettinadWarningContainer = Color(hex: 0xFEF3C7) // Amber 100
    static let onChettinadWarningContainer = Color(hex: 0x92400E) // Amber 800
    
    // Text
    static let chettinadTextPrimary = Color(hex: 0x111827) // Gray 900
    static let chettinadTextSecondary = Color(hex: 0x6B7280) // Gray 500
    
    // Borders
    static let chettinadOutline = Color(hex: 0xD1D5DB) // Gray 300
    static let chettinadOutlineVariant = Color(hex: 0xE5E7EB) // Gray 200
}

public extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 08) & 0xff) / 255,
            blue: Double((hex >> 00) & 0xff) / 255,
            opacity: alpha
        )
    }
}
