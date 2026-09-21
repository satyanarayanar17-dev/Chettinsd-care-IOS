import SwiftUI

public struct Typography {
    // We use standard iOS system fonts mapped to the Manrope scales from Stitch.
    // When the actual Manrope font is available, these can be replaced with .custom("Manrope", size: ...)
    
    public static let headlineLarge = Font.system(size: 32, weight: .bold, design: .default)
    public static let headlineMedium = Font.system(size: 28, weight: .bold, design: .default)
    public static let headlineSmall = Font.system(size: 24, weight: .semibold, design: .default)
    
    public static let titleLarge = Font.system(size: 22, weight: .semibold, design: .default)
    public static let titleMedium = Font.system(size: 18, weight: .bold, design: .default)
    public static let titleSmall = Font.system(size: 16, weight: .semibold, design: .default)
    
    public static let bodyLarge = Font.system(size: 16, weight: .regular, design: .default)
    public static let bodyMedium = Font.system(size: 14, weight: .regular, design: .default)
    public static let bodySmall = Font.system(size: 12, weight: .regular, design: .default)
    
    public static let labelLarge = Font.system(size: 14, weight: .medium, design: .default)
    public static let labelMedium = Font.system(size: 12, weight: .medium, design: .default)
    public static let labelSmall = Font.system(size: 11, weight: .medium, design: .default)
}

public struct ChettinadTextStyle: ViewModifier {
    let font: Font
    let color: Color
    
    public init(font: Font, color: Color = .chettinadTextPrimary) {
        self.font = font
        self.color = color
    }
    
    public func body(content: Content) -> some View {
        content
            .font(font)
            .foregroundColor(color)
    }
}

public extension View {
    func textStyle(_ font: Font, color: Color = .chettinadTextPrimary) -> some View {
        self.modifier(ChettinadTextStyle(font: font, color: color))
    }
}
