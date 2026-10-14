import SwiftUI
import CoreText

private final class FontBundleToken {}
public enum StitchTheme {
    public static func registerFonts() {
        if let url = Bundle(for: FontBundleToken.self).url(forResource: "Manrope", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

public struct StitchCard<Content: View>: View {
    let content: Content
    public init(@ViewBuilder content: () -> Content) { self.content = content() }
    public var body: some View {
        VStack(alignment: .leading, spacing: 16) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20).background(Color.surfaceContainerLowest)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.chettinadPrimary.opacity(0.035), radius: 8, y: 3)
    }
}

public struct StitchButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(Typography.labelLarge).fontWeight(.bold)
            .frame(maxWidth: .infinity).padding(.vertical, 16).padding(.horizontal, 16)
            .foregroundStyle(.white)
            .background(LinearGradient(colors: [.chettinadPrimary, Color(hex: 0x1A237E)], startPoint: .leading, endPoint: .trailing))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
    }
}

public struct StitchBadge: View {
    let label: String
    public init(_ label: String) { self.label = label }
    public var body: some View {
        Text(label.replacingOccurrences(of: "_", with: " ")).font(Typography.labelSmall).fontWeight(.semibold)
            .foregroundStyle(Color.chettinadPrimary).padding(.horizontal, 10).padding(.vertical, 6)
            .background(Color.chettinadPrimary.opacity(0.07)).clipShape(RoundedRectangle(cornerRadius: 5))
    }
}

public struct StitchLoginShell<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content
    public init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title; self.subtitle = subtitle; self.content = content()
    }
    public var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                HStack(spacing: 12) {
                    OfficialLogoSlot()
                    Text("CHETTINAD CARE").font(Typography.titleLarge).fontWeight(.heavy)
                }.foregroundStyle(Color.chettinadPrimary).padding(.top, 32)
                StitchCard {
                    VStack(spacing: 12) {
                        Text("INSTITUTIONAL PORTAL").font(Typography.labelSmall).tracking(2)
                        Text(LocalizedStringKey(title)).font(Typography.headlineLarge).foregroundStyle(Color.chettinadPrimary)
                        Text(LocalizedStringKey(subtitle)).font(Typography.bodyLarge).foregroundStyle(Color.chettinadSecondary).multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity).padding(.vertical, 20)
                    content
                }
                Label("Secure access to your care", systemImage: "lock.shield")
                    .font(Typography.bodySmall).foregroundStyle(Color.chettinadSecondary)
            }.padding(20).frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
        }.background(Color.chettinadBackground).scrollDismissesKeyboard(.interactively)
    }
}

public struct OfficialLogoSlot: View {
    public init() {}
    public var body: some View {
        if UIImage(named: "OfficialLogo") != nil {
            Image("OfficialLogo").resizable().scaledToFit().frame(width: 40, height: 40)
        } else {
            Text("LOGO").font(.system(size: 8, weight: .bold)).tracking(0.5).frame(width: 40, height: 40)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.chettinadOutline))
                .accessibilityLabel("Official logo asset required")
        }
    }
}

public extension View {
    func stitchField() -> some View {
        self.font(Typography.bodyLarge).padding(16)
            .background(Color.surfaceContainerLow).clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.chettinadOutline.opacity(0.4), lineWidth: 1))
    }
}

// MARK: - Spacing & Layout Constants
public enum StitchSpacing {
    public static let xs: CGFloat = 4
    public static let sm: CGFloat = 8
    public static let md: CGFloat = 12
    public static let lg: CGFloat = 16
    public static let xl: CGFloat = 24
    public static let xxl: CGFloat = 32
}

// MARK: - Standardized Buttons

public struct StitchPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.labelLarge).fontWeight(.bold)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, StitchSpacing.lg)
            .foregroundStyle(.white)
            .background(Color.chettinadPrimary)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

public struct StitchSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.labelLarge).fontWeight(.bold)
            .padding(.vertical, StitchSpacing.md)
            .padding(.horizontal, StitchSpacing.lg)
            .foregroundStyle(Color.chettinadPrimary)
            .background(Color.chettinadPrimary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.5)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

public struct StitchDestructiveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.labelLarge).fontWeight(.bold)
            .padding(.vertical, StitchSpacing.md)
            .padding(.horizontal, StitchSpacing.lg)
            .foregroundStyle(Color.chettinadError)
            .background(Color.chettinadErrorContainer)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.5)
    }
}

public struct StitchCompactButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var enabled
    public init() {}
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Typography.labelSmall).fontWeight(.bold)
            .padding(.vertical, StitchSpacing.sm)
            .padding(.horizontal, StitchSpacing.md)
            .foregroundStyle(Color.chettinadPrimary)
            .background(Color.chettinadPrimary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .opacity(enabled ? (configuration.isPressed ? 0.8 : 1) : 0.5)
    }
}

// MARK: - Status Chips

public struct StitchStatusChip: View {
    let status: String
    
    public init(status: String) {
        self.status = status
    }
    
    private var treatment: (bg: Color, fg: Color, icon: String?) {
        let normalized = status.uppercased().replacingOccurrences(of: " ", with: "_")
        switch normalized {
        case "COMPLETED", "TAKEN", "CONFIRMED", "CHECKED_IN", "READY_FOR_DOCTOR":
            return (.chettinadSuccessContainer, .onChettinadSuccessContainer, "checkmark.circle.fill")
        case "PENDING", "PENDING_CONFIRMATION", "WAITING", "WAITING_DOCTOR", "DUE", "UPCOMING":
            return (.chettinadWarningContainer, .onChettinadWarningContainer, "clock.fill")
        case "IN_TRIAGE", "IN_CONSULTATION":
            return (.chettinadPrimary.opacity(0.15), .chettinadPrimary, "stethoscope")
        case "CANCELLED", "NO_SHOW", "MISSED":
            return (.chettinadErrorContainer, .onChettinadErrorContainer, "xmark.circle.fill")
        case "SKIPPED":
            return (.surfaceContainerHigh, .chettinadTextSecondary, "arrow.uturn.right.circle.fill")
        default:
            return (.surfaceContainerHigh, .chettinadTextSecondary, nil)
        }
    }
    
    public var body: some View {
        HStack(spacing: StitchSpacing.xs) {
            if let icon = treatment.icon {
                Image(systemName: icon).font(.system(size: 10, weight: .bold))
            }
            Text(status.replacingOccurrences(of: "_", with: " ").capitalized)
                .font(Typography.labelSmall).fontWeight(.bold)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, StitchSpacing.md)
        .foregroundStyle(treatment.fg)
        .background(treatment.bg)
        .clipShape(Capsule())
    }
}

// MARK: - Empty & Error States

public struct StitchEmptyState: View {
    let icon: String
    let title: String
    let message: String
    let ctaTitle: String?
    let action: (() -> Void)?
    
    public init(icon: String, title: String, message: String, ctaTitle: String? = nil, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
        self.ctaTitle = ctaTitle
        self.action = action
    }
    
    public var body: some View {
        VStack(spacing: StitchSpacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundStyle(Color.chettinadOutline)
            VStack(spacing: StitchSpacing.sm) {
                Text(LocalizedStringKey(title))
                    .font(Typography.titleMedium)
                    .foregroundStyle(Color.chettinadTextPrimary)
                Text(message)
                    .font(Typography.bodyMedium)
                    .foregroundStyle(Color.chettinadTextSecondary)
                    .multilineTextAlignment(.center)
            }
            if let ctaTitle = ctaTitle, let action = action {
                Button(action: action) {
                    Text(ctaTitle)
                }
                .buttonStyle(StitchSecondaryButtonStyle())
                .padding(.top, StitchSpacing.sm)
            }
        }
        .padding(StitchSpacing.xxl)
        .frame(maxWidth: .infinity)
    }
}

public struct StitchErrorState: View {
    let message: String
    let retryAction: (() -> Void)?
    
    public init(message: String, retryAction: (() -> Void)? = nil) {
        self.message = message
        self.retryAction = retryAction
    }
    
    public var body: some View {
        VStack(spacing: StitchSpacing.lg) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.chettinadWarning)
            VStack(spacing: StitchSpacing.sm) {
                Text("Something went wrong")
                    .font(Typography.titleMedium)
                    .foregroundStyle(Color.chettinadTextPrimary)
                Text(message)
                    .font(Typography.bodyMedium)
                    .foregroundStyle(Color.chettinadTextSecondary)
                    .multilineTextAlignment(.center)
            }
            if let retryAction = retryAction {
                Button(action: retryAction) {
                    Text("Retry")
                }
                .buttonStyle(StitchSecondaryButtonStyle())
            }
        }
        .padding(StitchSpacing.xxl)
        .frame(maxWidth: .infinity)
        .background(Color.surfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

public struct InterfaceLanguagePicker: View {
    @AppStorage("interface-language") private var language = "en"
    public init() {}
    public var body: some View {
        Picker("Language",selection:$language) {
            Text("English").tag("en")
            Text("தமிழ்").tag("ta")
            Text("తెలుగు").tag("te")
        }
    }
}

public struct DemoEnvironmentBanner: View {
    public init() {}
    public var body: some View {
        Text("Demo · use synthetic patient details").font(.caption).frame(maxWidth:.infinity).padding(8).background(Color.yellow.opacity(0.18))
    }
}
