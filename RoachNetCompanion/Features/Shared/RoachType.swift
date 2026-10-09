import SwiftUI

/// RoachNet v4 type scale. Inter for people-language, JetBrains Mono for anything
/// technical (overlines, labels, readouts, versions, paths). Both are bundled (OFL)
/// and registered through `UIAppFonts`; every style scales with Dynamic Type.
enum RoachType {
    static func inter(_ size: CGFloat, _ weight: Font.Weight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(interName(weight), size: size, relativeTo: style)
    }

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .medium, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(monoName(weight), size: size, relativeTo: style)
    }

    // Display and titles (Inter 800 with tight tracking; see `roachTracking`).
    static func display(_ size: CGFloat) -> Font { inter(size, .heavy, relativeTo: .largeTitle) }
    static let statement = display(34)
    static let pageTitle = display(28)
    static let cardTitle = inter(20, .bold, relativeTo: .title3)
    static let itemTitle = inter(16, .semibold, relativeTo: .headline)

    // Text.
    static let lede = inter(17, .regular, relativeTo: .body)
    static let body = inter(15, .regular, relativeTo: .body)
    static let bodySmall = inter(13.5, .regular, relativeTo: .subheadline)
    static let button = inter(15, .semibold, relativeTo: .body)
    static let caption = inter(12, .regular, relativeTo: .caption)
    static func caption(_ weight: Font.Weight) -> Font { inter(12, weight, relativeTo: .caption) }
    static let caption2 = inter(11, .regular, relativeTo: .caption2)
    static func caption2(_ weight: Font.Weight) -> Font { inter(11, weight, relativeTo: .caption2) }
    static func subheadline(_ weight: Font.Weight = .regular) -> Font { inter(15, weight, relativeTo: .subheadline) }
    static func headline(_ weight: Font.Weight = .semibold) -> Font { inter(17, weight, relativeTo: .headline) }
    static func title3(_ weight: Font.Weight = .semibold) -> Font { inter(20, weight, relativeTo: .title3) }

    // Machine.
    static let overline = mono(11.5, .heavy, relativeTo: .caption)
    static let label = mono(10.5, .bold, relativeTo: .caption2)
    static let tab = mono(9, .bold, relativeTo: .caption2)
    static let code = mono(13, .regular, relativeTo: .footnote)
    static let readout = mono(26, .bold, relativeTo: .title)
    static func readout(_ size: CGFloat) -> Font { mono(size, .bold, relativeTo: .title) }

    static func interName(_ weight: Font.Weight) -> String {
        switch weight {
        case .medium: return "Inter-Medium"
        case .semibold: return "Inter-SemiBold"
        case .bold: return "Inter-Bold"
        case .heavy, .black: return "Inter-ExtraBold"
        default: return "Inter-Regular"
        }
    }

    static func monoName(_ weight: Font.Weight) -> String {
        switch weight {
        case .regular, .light, .thin, .ultraLight: return "JetBrainsMono-Regular"
        case .semibold, .bold: return "JetBrainsMono-Bold"
        case .heavy, .black: return "JetBrainsMono-ExtraBold"
        default: return "JetBrainsMono-Medium"
        }
    }
}

extension View {
    /// Inter 800 headline with the v4 negative tracking (-0.035em).
    func roachDisplay(_ size: CGFloat) -> some View {
        font(RoachType.display(size)).tracking(-size * 0.035)
    }

    /// JetBrains Mono caps with the v4 overline tracking (0.14em).
    func roachMonoCaps(_ font: Font = RoachType.overline, size: CGFloat = 11.5, tracking: CGFloat = 0.14) -> some View {
        self.font(font).tracking(size * tracking).textCase(.uppercase)
    }
}
