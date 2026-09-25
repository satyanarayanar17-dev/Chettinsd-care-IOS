import SwiftUI

public struct Typography {
    // Bundled Manrope matches the supplied Stitch design and scales with Dynamic Type.
    
    public static let headlineLarge = Font.custom("Manrope-Regular", size: 32).weight(.bold)
    public static let headlineMedium = Font.custom("Manrope-Regular", size: 28).weight(.bold)
    public static let headlineSmall = Font.custom("Manrope-Regular", size: 24).weight(.semibold)
    
    public static let titleLarge = Font.custom("Manrope-Regular", size: 22).weight(.semibold)
    public static let titleMedium = Font.custom("Manrope-Regular", size: 18).weight(.bold)
    public static let titleSmall = Font.custom("Manrope-Regular", size: 16).weight(.semibold)
    
    public static let bodyLarge = Font.custom("Manrope-Regular", size: 16).weight(.regular)
    public static let bodyMedium = Font.custom("Manrope-Regular", size: 14).weight(.regular)
    public static let bodySmall = Font.custom("Manrope-Regular", size: 12).weight(.regular)
    
    public static let labelLarge = Font.custom("Manrope-Regular", size: 14).weight(.medium)
    public static let labelMedium = Font.custom("Manrope-Regular", size: 12).weight(.medium)
    public static let labelSmall = Font.custom("Manrope-Regular", size: 11).weight(.medium)
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
