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
                        Text(title).font(Typography.headlineLarge).foregroundStyle(Color.chettinadPrimary)
                        Text(subtitle).font(Typography.bodyLarge).foregroundStyle(Color.chettinadSecondary).multilineTextAlignment(.center)
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
