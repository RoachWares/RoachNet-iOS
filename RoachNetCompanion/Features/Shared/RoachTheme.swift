import Observation
import SwiftUI
import os

enum RoachTheme {
    private static var palette: CompanionPalette { CompanionThemeRuntime.shared.palette }

    static var void: Color { palette.void }
    static var background: Color { palette.background }
    static var backgroundRaised: Color { palette.backgroundRaised }
    static var surface: Color { palette.surface }
    static var elevatedSurface: Color { palette.elevatedSurface }
    static var panelSoft: Color { palette.panelSoft }
    static var panelGlass: Color { palette.panelGlass }
    static var glassHighlight: Color { palette.glassHighlight }
    static var border: Color { palette.border }
    static var elevatedBorder: Color { palette.elevatedBorder }

    static var primary: Color { palette.primary }
    static var purpleInk: Color { palette.purpleInk }
    static var purpleDeep: Color { palette.purpleDeep }
    static var secondary: Color { palette.secondary }
    static var signalDeep: Color { palette.signalDeep }
    static var onSignal: Color { palette.onSignal }
    static var cyan: Color { palette.cyan }
    static var tertiary: Color { palette.tertiary }
    static var amber: Color { palette.amber }
    static var warning: Color { palette.warning }
    static var hazard: Color { palette.hazard }

    static var text: Color { palette.text }
    static var subduedText: Color { palette.subduedText }
    static var softText: Color { palette.softText }

    static var neutralInk: Color { palette.neutralInk }
    static var isDark: Bool { palette.isDark }

    static var radiusCard: CGFloat { 18 * palette.radiusScale }
    static var radiusHero: CGFloat { 24 * palette.radiusScale }
    static var radiusButton: CGFloat { 10 * palette.radiusScale }

    static func ink(for accent: Color) -> Color {
        accent == primary ? purpleInk : accent
    }
}

struct CompanionPalette: Sendable, Equatable {
    var void: Color
    var background: Color
    var backgroundRaised: Color
    var surface: Color
    var elevatedSurface: Color
    var panelSoft: Color
    var panelGlass: Color
    var glassHighlight: Color
    var border: Color
    var elevatedBorder: Color
    var primary: Color
    var purpleInk: Color
    var purpleDeep: Color
    var secondary: Color
    var signalDeep: Color
    var onSignal: Color
    var cyan: Color
    var tertiary: Color
    var amber: Color
    var warning: Color
    var hazard: Color
    var text: Color
    var subduedText: Color
    var softText: Color
    var neutralInk: Color
    var isDark: Bool
    var radiusScale: CGFloat
    var sourceName: String?

    static let companionDefault = CompanionPalette(
        void: .black,
        background: Color(hex: 0x05060A),
        backgroundRaised: Color(hex: 0x090A0F),
        surface: Color(hex: 0x0C0D13),
        elevatedSurface: Color(hex: 0x13141C),
        panelSoft: Color(hex: 0x1B1C26),
        panelGlass: Color.white.opacity(0.04),
        glassHighlight: Color.white.opacity(0.055),
        border: Color.white.opacity(0.08),
        elevatedBorder: Color.white.opacity(0.14),
        primary: Color(hex: 0x9138D8),
        purpleInk: Color(hex: 0xB06CF0),
        purpleDeep: Color(hex: 0x1C0D2E),
        secondary: Color(hex: 0x36FF84),
        signalDeep: Color(hex: 0x0A2817),
        onSignal: Color(hex: 0x03140A),
        cyan: Color(hex: 0x48E6FF),
        tertiary: Color(hex: 0x4D8DFF),
        amber: Color(hex: 0xFF9A45),
        warning: Color(hex: 0xEDBA42),
        hazard: Color(hex: 0xFF5A36),
        text: Color(hex: 0xF0F0F0),
        subduedText: Color(hex: 0x9A9AA2),
        softText: Color(hex: 0x6F6F78),
        neutralInk: .white,
        isDark: true,
        radiusScale: 1,
        sourceName: nil
    )
}

extension CompanionPalette {
    init?(macTheme theme: CompanionMacTheme) {
        func token(_ key: String) -> CompanionRGBA? { theme.palette[key].flatMap(CompanionRGBA.init(hex:)) }
        guard let background = token("background"), let text = token("text"), let accent = token("accent") else {
            return nil
        }
        let window = background.composited(over: .black)
        let panel = (token("panel") ?? window).composited(over: window)
        let panelRaised = (token("panelRaised") ?? panel).composited(over: window)
        let second = token("accentSecondary") ?? accent
        let info = token("accentInfo") ?? accent
        let third = token("accentTertiary") ?? token("warning") ?? accent
        let ink = token("ink") ?? text.opaque
        let muted = (token("muted") ?? text.withAlpha(0.68))
        let textOpaque = text.composited(over: panel)
        let isDark = theme.mode != "light"

        var readable = second.composited(over: panel)
        var step = 0.0
        while CompanionRGBA.contrast(readable, panel) < 4.5 && step < 1 {
            step += 0.1
            readable = second.composited(over: panel).mixed(with: textOpaque, amount: step)
        }

        self.init(
            void: (token("shade") ?? .black).color,
            background: window.color,
            backgroundRaised: (token("backgroundRaised") ?? window).composited(over: window).color,
            surface: panel.color,
            elevatedSurface: panelRaised.color,
            panelSoft: (token("panelSoft") ?? panelRaised).composited(over: window).color,
            panelGlass: (token("glass") ?? ink.withAlpha(0.04)).color,
            glassHighlight: (token("specular") ?? ink.withAlpha(0.055)).color,
            border: (token("border") ?? ink.withAlpha(0.08)).color,
            elevatedBorder: (token("borderStrong") ?? ink.withAlpha(0.14)).color,
            primary: second.opaque.color,
            purpleInk: readable.color,
            purpleDeep: second.opaque.mixed(with: window, amount: 0.82).color,
            secondary: accent.opaque.color,
            signalDeep: accent.opaque.mixed(with: window, amount: 0.82).color,
            onSignal: (token("onAccent") ?? (isDark ? .black : .white)).color,
            cyan: info.opaque.color,
            tertiary: info.opaque.color,
            amber: third.opaque.color,
            warning: (token("warning") ?? third).opaque.color,
            hazard: (token("danger") ?? CompanionRGBA(red: 1, green: 0.35, blue: 0.21)).opaque.color,
            text: textOpaque.color,
            subduedText: muted.composited(over: panel).color,
            softText: muted.multiplyingAlpha(by: 0.75).composited(over: panel).color,
            neutralInk: ink.opaque.color,
            isDark: isDark,
            radiusScale: CGFloat(min(2, max(0, theme.shape?.radiusScale ?? 1))),
            sourceName: theme.name
        )
    }
}

struct CompanionMacTheme: Codable, Sendable, Equatable {
    struct Shape: Codable, Sendable, Equatable {
        var radiusScale: Double?
    }

    var schema: String
    var id: String
    var name: String
    var mode: String
    var revision: Int?
    var palette: [String: String]
    var shape: Shape?

    static let schemaID = "org.roachnet.active-theme.v1"
}

struct CompanionRGBA: Sendable, Equatable {
    var red: Double
    var green: Double
    var blue: Double
    var alpha: Double

    static let black = CompanionRGBA(red: 0, green: 0, blue: 0)
    static let white = CompanionRGBA(red: 1, green: 1, blue: 1)

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = min(1, max(0, red))
        self.green = min(1, max(0, green))
        self.blue = min(1, max(0, blue))
        self.alpha = min(1, max(0, alpha))
    }

    init?(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") { text.removeFirst() }
        guard text.count == 6 || text.count == 8, let value = UInt64(text, radix: 16) else { return nil }
        if text.count == 6 {
            self.init(
                red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255,
                blue: Double(value & 0xFF) / 255)
        } else {
            self.init(
                red: Double((value >> 24) & 0xFF) / 255,
                green: Double((value >> 16) & 0xFF) / 255,
                blue: Double((value >> 8) & 0xFF) / 255,
                alpha: Double(value & 0xFF) / 255
            )
        }
    }

    var color: Color { Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha) }
    var opaque: CompanionRGBA { withAlpha(1) }
    func withAlpha(_ value: Double) -> CompanionRGBA { CompanionRGBA(red: red, green: green, blue: blue, alpha: value) }
    func multiplyingAlpha(by factor: Double) -> CompanionRGBA { withAlpha(alpha * factor) }

    func mixed(with other: CompanionRGBA, amount: Double) -> CompanionRGBA {
        let t = min(1, max(0, amount))
        return CompanionRGBA(
            red: red + (other.red - red) * t,
            green: green + (other.green - green) * t,
            blue: blue + (other.blue - blue) * t,
            alpha: alpha + (other.alpha - alpha) * t
        )
    }

    func composited(over base: CompanionRGBA) -> CompanionRGBA {
        CompanionRGBA(
            red: red * alpha + base.red * (1 - alpha),
            green: green * alpha + base.green * (1 - alpha),
            blue: blue * alpha + base.blue * (1 - alpha)
        )
    }

    var luminance: Double {
        func channel(_ value: Double) -> Double { value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4) }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    static func contrast(_ a: CompanionRGBA, _ b: CompanionRGBA) -> Double {
        let x = a.luminance
        let y = b.luminance
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
}

final class CompanionThemeRuntime: Observable, @unchecked Sendable {
    static let shared = CompanionThemeRuntime()

    private static let followsMacKey = "roachnet.companion.theme.followsMac"
    private static let lastThemeKey = "roachnet.companion.theme.lastMacTheme.v1"

    private let registrar = ObservationRegistrar()
    private let state: OSAllocatedUnfairLock<State>

    private struct State: Sendable {
        var palette: CompanionPalette
        var followsMac: Bool
        var macTheme: CompanionMacTheme?
    }

    init(defaults: UserDefaults = .standard) {
        let follows = defaults.object(forKey: Self.followsMacKey) as? Bool ?? true
        let saved = defaults.data(forKey: Self.lastThemeKey).flatMap {
            try? JSONDecoder().decode(CompanionMacTheme.self, from: $0)
        }
        let palette = follows ? saved.flatMap(CompanionPalette.init(macTheme:)) ?? .companionDefault : .companionDefault
        state = OSAllocatedUnfairLock(initialState: State(palette: palette, followsMac: follows, macTheme: saved))
    }

    var palette: CompanionPalette {
        registrar.access(self, keyPath: \.palette)
        return state.withLock { $0.palette }
    }

    var followsMac: Bool {
        registrar.access(self, keyPath: \.followsMac)
        return state.withLock { $0.followsMac }
    }

    var macTheme: CompanionMacTheme? {
        registrar.access(self, keyPath: \.macTheme)
        return state.withLock { $0.macTheme }
    }

    func setFollowsMac(_ follows: Bool, defaults: UserDefaults = .standard) {
        defaults.set(follows, forKey: Self.followsMacKey)
        registrar.withMutation(of: self, keyPath: \.followsMac) {
            state.withLock { $0.followsMac = follows }
        }
        applyPalette()
    }

    func receive(_ theme: CompanionMacTheme?, defaults: UserDefaults = .standard) {
        let usable = theme.flatMap { $0.schema == CompanionMacTheme.schemaID ? $0 : nil }
        if let usable, let data = try? JSONEncoder().encode(usable) {
            defaults.set(data, forKey: Self.lastThemeKey)
        }
        guard usable != state.withLock({ $0.macTheme }) else { return }
        registrar.withMutation(of: self, keyPath: \.macTheme) {
            state.withLock { $0.macTheme = usable ?? $0.macTheme }
        }
        applyPalette()
    }

    private func applyPalette() {
        let next = state.withLock { current -> CompanionPalette in
            guard current.followsMac, let theme = current.macTheme else { return .companionDefault }
            return CompanionPalette(macTheme: theme) ?? .companionDefault
        }
        guard next != state.withLock({ $0.palette }) else { return }
        registrar.withMutation(of: self, keyPath: \.palette) {
            state.withLock { $0.palette = next }
        }
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

struct RoachBackdrop: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    RoachTheme.background

                    auroraBlob(
                        RoachTheme.tertiary, diameter: size.width * 1.1, period: 34, t: t,
                        base: CGPoint(x: size.width * 0.15, y: size.height * 0.08), size: size)
                    auroraBlob(
                        RoachTheme.primary, diameter: size.width * 1.0, period: 43, t: t + 11,
                        base: CGPoint(x: size.width * 0.95, y: size.height * 0.22), size: size)
                    auroraBlob(
                        RoachTheme.secondary, diameter: size.width * 0.8, period: 51, t: t + 23,
                        base: CGPoint(x: size.width * 0.3, y: size.height * 0.9), size: size, strength: 0.10)

                    RoachDotField()
                        .opacity(0.5)

                    if !reduceMotion {
                        let progress = (t.truncatingRemainder(dividingBy: 18)) / 18
                        LinearGradient(
                            colors: [.clear, RoachTheme.cyan.opacity(0.07), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 90)
                        .offset(y: -size.height / 2 - 45 + (size.height + 90) * progress)
                        .blendMode(.screen)
                    }
                }
                .frame(width: size.width, height: size.height)
            }
            .ignoresSafeArea()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func auroraBlob(
        _ color: Color,
        diameter: CGFloat,
        period: Double,
        t: Double,
        base: CGPoint,
        size: CGSize,
        strength: Double = 0.16
    ) -> some View {
        let phase = (t / period) * 2 * .pi
        return Circle()
            .fill(
                RadialGradient(
                    colors: [color.opacity(strength), .clear], center: .center, startRadius: 0, endRadius: diameter / 2)
            )
            .frame(width: diameter, height: diameter)
            .position(
                x: base.x + CGFloat(sin(phase)) * size.width * 0.10,
                y: base.y + CGFloat(cos(phase * 0.8)) * size.height * 0.05
            )
            .blur(radius: 40)
            .blendMode(.screen)
    }
}

struct RoachDotField: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 22
            var y: CGFloat = 0
            var row = 0
            while y < size.height {
                var x: CGFloat = row.isMultiple(of: 2) ? 0 : step / 2
                let fade = max(0, 1 - y / (size.height * 0.75))
                while x < size.width {
                    let rect = CGRect(x: x, y: y, width: 1.2, height: 1.2)
                    let color = row.isMultiple(of: 3) ? RoachTheme.purpleInk : RoachTheme.secondary
                    context.fill(Path(ellipseIn: rect), with: .color(color.opacity(0.10 * fade)))
                    x += step
                }
                y += step
                row += 1
            }
        }
        .allowsHitTesting(false)
    }
}

struct RoachTopChromeScrim: View {
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            LinearGradient(
                colors: [RoachTheme.background.opacity(0.96), RoachTheme.background.opacity(0.7), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: max(proxy.safeAreaInsets.top + 8, 60))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea(edges: .top)
        }
        .allowsHitTesting(false)
    }
}

struct RoachBottomChromeScrim: View {
    let accent: Color

    var body: some View {
        LinearGradient(
            colors: [.clear, RoachTheme.background.opacity(0.55), RoachTheme.background.opacity(0.9)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
    }
}

struct RoachCardBackground: View {
    var cornerRadius: CGFloat = RoachTheme.radiusCard
    var glow: Color = RoachTheme.secondary
    var glowStrength: Double = 0.08
    var borderColor: Color = RoachTheme.border

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        shape
            .fill(
                LinearGradient(
                    colors: [RoachTheme.elevatedSurface.opacity(0.82), RoachTheme.void.opacity(0.74)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                shape.fill(
                    RadialGradient(
                        colors: [glow.opacity(glowStrength), .clear], center: .top, startRadius: 0, endRadius: 220)
                )
            )
            .overlay(shape.strokeBorder(borderColor, lineWidth: 1))
            .overlay(alignment: .top) {
                shape
                    .strokeBorder(
                        LinearGradient(
                            colors: [RoachTheme.glassHighlight, .clear], startPoint: .top, endPoint: .center),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.28), radius: 24, x: 0, y: 18)
    }
}

struct RoachPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(14)
            .background(RoachCardBackground())
    }
}

struct RoachHeroPanel<Content: View>: View {
    let accent: Color
    let content: Content

    init(accent: Color = RoachTheme.primary, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(
                ZStack {
                    RoachCardBackground(cornerRadius: RoachTheme.radiusHero, glow: accent, glowStrength: 0.14)
                    RoundedRectangle(cornerRadius: RoachTheme.radiusHero, style: .continuous)
                        .fill(
                            RadialGradient(
                                colors: [accent.opacity(0.20), .clear], center: .topTrailing, startRadius: 0,
                                endRadius: 260))
                }
            )
    }
}

struct RoachDot: View {
    let accent: Color
    var size: CGFloat = 7

    var body: some View {
        Circle()
            .fill(accent)
            .frame(width: size, height: size)
            .shadow(color: accent.opacity(0.6), radius: 5)
            .accessibilityHidden(true)
    }
}

struct RoachOverline: View {
    let text: String
    var accent: Color = RoachTheme.secondary
    var showsChevron = true

    var body: some View {
        HStack(spacing: 6) {
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 8, weight: .black))
                    .accessibilityHidden(true)
            }
            Text(text)
                .roachMonoCaps()
                .lineLimit(1)
        }
        .foregroundStyle(RoachTheme.ink(for: accent))
    }
}

struct RoachBadge: View {
    let title: String
    let accent: Color

    var body: some View {
        Text(title)
            .roachMonoCaps(RoachType.label, size: 10.5, tracking: 0.1)
            .foregroundStyle(RoachTheme.ink(for: accent))
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(accent.opacity(0.12))
                    .overlay(Capsule(style: .continuous).strokeBorder(accent.opacity(0.38), lineWidth: 1))
            )
    }
}

struct RoachStatusPill: View {
    let title: String
    let accent: Color

    var body: some View {
        HStack(spacing: 8) {
            RoachDot(accent: accent)
            Text(title)
                .font(RoachType.caption(.semibold))
                .foregroundStyle(RoachTheme.text)
                .lineLimit(1)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(
            Capsule(style: .continuous)
                .fill(RoachTheme.surface.opacity(0.92))
                .overlay(Capsule(style: .continuous).strokeBorder(accent.opacity(0.26), lineWidth: 1))
        )
        .accessibilityElement(children: .combine)
    }
}

struct RoachActionPill: View {
    let title: String
    let systemImage: String
    let accent: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(RoachTheme.ink(for: accent))
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(accent.opacity(0.14))
                        .overlay(Circle().strokeBorder(accent.opacity(0.32), lineWidth: 1))
                )

            Text(title)
                .font(RoachType.subheadline(.semibold))
                .foregroundStyle(RoachTheme.text)
                .lineLimit(1)

            Spacer(minLength: 0)

            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(RoachTheme.softText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minHeight: 44)
        .background(
            Capsule(style: .continuous)
                .fill(RoachTheme.surface.opacity(0.92))
                .overlay(Capsule(style: .continuous).strokeBorder(RoachTheme.border, lineWidth: 1))
        )
    }
}

struct RoachStatusRow: View {
    let name: String
    var subtitle: String?
    let value: String
    let accent: Color

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            RoachDot(accent: accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(RoachType.subheadline(.semibold))
                    .foregroundStyle(RoachTheme.text)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(RoachType.caption)
                        .foregroundStyle(RoachTheme.subduedText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            Text(value)
                .roachMonoCaps(RoachType.label, size: 10.5, tracking: 0.12)
                .foregroundStyle(RoachTheme.ink(for: accent))
                .lineLimit(1)
        }
        .padding(.vertical, 11)
        .accessibilityElement(children: .combine)
    }
}

struct RoachToast: View {
    let title: String
    let detail: String?
    let accent: Color
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            RoachDot(accent: accent)
            (Text(title).font(RoachType.subheadline(.bold)).foregroundColor(RoachTheme.text)
                + Text(detail.map { " \($0)" } ?? "").font(RoachType.subheadline()).foregroundColor(
                    RoachTheme.subduedText))
                .lineLimit(3)
            Spacer(minLength: 4)
            if let onDismiss {
                Button("OK", action: onDismiss)
                    .buttonStyle(RoachButtonStyle(kind: .secondary, size: .compact))
                    .accessibilityIdentifier("toast.dismiss")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(Capsule(style: .continuous).fill(RoachTheme.elevatedSurface.opacity(0.82)))
                .overlay(Capsule(style: .continuous).strokeBorder(RoachTheme.border, lineWidth: 1))
                .shadow(color: .black.opacity(0.5), radius: 29, x: 0, y: 20)
        )
        .accessibilityElement(children: .combine)
    }
}

struct RoachSignalCore: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var size: CGFloat = 120

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: reduceMotion)) { context in
            let t = reduceMotion ? 0 : context.date.timeIntervalSinceReferenceDate
            let pulse = 0.9 + 0.1 * sin(t * 2 * .pi / 2.8)
            let breathe = 1 + 0.03 * sin(t * 2 * .pi / 4.6)
            ZStack {
                Capsule(style: .continuous)
                    .strokeBorder(RoachTheme.neutralInk.opacity(0.10), lineWidth: 1)
                    .frame(width: size * 1.7, height: size * 0.92)
                Capsule(style: .continuous)
                    .strokeBorder(RoachTheme.purpleInk.opacity(0.28), lineWidth: 1)
                    .frame(width: size * 1.36, height: size * 0.7)
                    .scaleEffect(breathe)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [RoachTheme.purpleInk, RoachTheme.primary, RoachTheme.purpleDeep],
                            center: .topLeading, startRadius: 2, endRadius: size * 0.36)
                    )
                    .frame(width: size * 0.42, height: size * 0.42)
                    .shadow(color: RoachTheme.primary.opacity(0.55), radius: 30)
                    .scaleEffect(pulse)
            }
            .frame(width: size * 1.7, height: size)
        }
        .accessibilityHidden(true)
    }
}

struct RoachTabBarItem: Identifiable {
    let tab: CompanionTab
    let title: String
    let systemImage: String
    let accent: Color

    var id: CompanionTab { tab }
}

enum RoachCompanionChrome {
    static let tabBarAvoidance: CGFloat = 0
    static let bottomContentClearance: CGFloat = 28
}

extension EnvironmentValues {
    @Entry var roachTabBarMinY: CGFloat = .infinity
}

struct RoachTabBarOverlap: ViewModifier {
    @Environment(\.roachTabBarMinY) private var tabBarMinY
    @Binding var overlap: CGFloat
    @State private var frameMaxY: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .onGeometryChange(for: CGFloat.self) {
                $0.frame(in: .global).maxY
            } action: { maxY in
                frameMaxY = maxY
                update()
            }
            .onChange(of: tabBarMinY) { _, _ in update() }
    }

    private func update() {
        let value = tabBarMinY.isFinite ? max(0, (frameMaxY - tabBarMinY).rounded()) : 0
        if abs(value - overlap) >= 1 { overlap = value }
    }
}

struct RoachTabBarScrollClearance: ViewModifier {
    @State private var overlap: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .contentMargins(.bottom, overlap, for: .scrollContent)
            .modifier(RoachTabBarOverlap(overlap: $overlap))
    }
}

extension View {
    func roachTabBarOverlap(_ overlap: Binding<CGFloat>) -> some View {
        modifier(RoachTabBarOverlap(overlap: overlap))
    }

    func roachTabBarScrollClearance() -> some View {
        modifier(RoachTabBarScrollClearance())
    }
}

struct RoachFloatingTabBar: View {
    @Binding var selection: CompanionTab
    let items: [RoachTabBarItem]
    @Namespace private var tabSelection

    var body: some View {
        HStack(spacing: 2) {
            ForEach(items) { item in
                let isSelected = selection == item.tab
                Button {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) { selection = item.tab }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(isSelected ? RoachTheme.secondary : RoachTheme.softText)
                            .frame(height: 20)
                        Text(item.title)
                            .roachMonoCaps(RoachType.tab, size: 9, tracking: 0.08)
                            .foregroundStyle(isSelected ? Color(hex: 0xF7FFE9) : RoachTheme.softText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background {
                        if isSelected {
                            Capsule(style: .continuous)
                                .fill(RoachTheme.signalDeep)
                                .overlay(
                                    Capsule(style: .continuous)
                                        .fill(
                                            RadialGradient(
                                                colors: [RoachTheme.secondary.opacity(0.26), .clear], center: .bottom,
                                                startRadius: 0, endRadius: 46))
                                )
                                .overlay(
                                    Capsule(style: .continuous).strokeBorder(
                                        RoachTheme.secondary.opacity(0.22), lineWidth: 1)
                                )
                                .shadow(color: RoachTheme.secondary.opacity(0.12), radius: 12)
                                .matchedGeometryEffect(id: "tabSelection", in: tabSelection)
                        }
                    }
                    .contentShape(Capsule(style: .continuous))
                }
                .buttonStyle(RoachPressableButtonStyle(scale: 0.96))
                .accessibilityLabel(item.title)
                .accessibilityIdentifier("tab.\(item.tab.identifier)")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(6)
        .background(
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(Capsule(style: .continuous).fill(RoachTheme.elevatedSurface.opacity(0.82)))
                .overlay(Capsule(style: .continuous).strokeBorder(RoachTheme.border, lineWidth: 1))
                .overlay(alignment: .top) {
                    Capsule(style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [RoachTheme.neutralInk.opacity(0.09), .clear], startPoint: .top,
                                endPoint: .center), lineWidth: 1)
                }
                .shadow(color: .black.opacity(0.5), radius: 29, x: 0, y: 20)
        )
    }
}

struct RoachButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, signal, ghost, danger }
    enum Size { case regular, compact }

    var kind: Kind = .secondary
    var size: Size = .regular

    func makeBody(configuration: Configuration) -> some View {
        RoachButtonBody(configuration: configuration, kind: kind, size: size)
    }
}

private struct RoachButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: RoachButtonStyle.Kind
    let size: RoachButtonStyle.Size
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: RoachTheme.radiusButton, style: .continuous)
        configuration.label
            .font(size == .compact ? RoachType.caption(.semibold) : RoachType.button)
            .lineLimit(1)
            .padding(.horizontal, size == .compact ? 12 : 16)
            .frame(minHeight: size == .compact ? 32 : 44)
            .foregroundStyle(foreground)
            .background {
                switch kind {
                case .primary:
                    shape.fill(RoachTheme.primary)
                        .shadow(color: RoachTheme.primary.opacity(isEnabled ? 0.35 : 0), radius: 16, x: 0, y: 12)
                case .secondary:
                    shape.fill(RoachTheme.void).overlay(
                        shape.strokeBorder(RoachTheme.neutralInk.opacity(0.14), lineWidth: 1))
                case .signal:
                    shape.fill(RoachTheme.signalDeep).overlay(
                        shape.strokeBorder(RoachTheme.secondary.opacity(0.32), lineWidth: 1))
                case .ghost:
                    shape.fill(Color.clear)
                case .danger:
                    shape.fill(RoachTheme.hazard.opacity(0.12)).overlay(
                        shape.strokeBorder(RoachTheme.hazard.opacity(0.4), lineWidth: 1))
                }
            }
            .contentShape(shape)
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(configuration.isPressed ? 0.972 : 1)
            .brightness(configuration.isPressed ? 0.04 : 0)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
    }

    private var foreground: AnyShapeStyle {
        switch kind {
        case .primary: return AnyShapeStyle(Color.white)
        case .secondary, .ghost: return AnyShapeStyle(TintShapeStyle.tint)
        case .signal: return AnyShapeStyle(RoachTheme.secondary)
        case .danger: return AnyShapeStyle(RoachTheme.hazard)
        }
    }
}

struct RoachPressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.975

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .brightness(configuration.isPressed ? 0.04 : 0)
            .animation(.spring(response: 0.22, dampingFraction: 0.74), value: configuration.isPressed)
    }
}

struct RoachShellDock: View {
    let title: String
    let detail: String
    let accent: Color
    let status: String
    let secondaryStatus: String

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 14) {
                shellMark
                shellCopy
                Spacer(minLength: 8)
                shellBadges
            }
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 14) {
                    shellMark
                    shellCopy
                }
                shellBadges
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoachCardBackground(cornerRadius: RoachTheme.radiusHero, glow: accent, glowStrength: 0.1))
    }

    private var shellMark: some View {
        Image(systemName: "point.3.connected.trianglepath.dotted")
            .font(.system(size: 16, weight: .bold))
            .foregroundStyle(RoachTheme.ink(for: accent))
            .frame(width: 44, height: 44)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(accent.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(
                            accent.opacity(0.32), lineWidth: 1))
            )
            .accessibilityHidden(true)
    }

    private var shellCopy: some View {
        VStack(alignment: .leading, spacing: 4) {
            RoachOverline(text: title, accent: accent, showsChevron: false)
            Text(detail)
                .font(RoachType.subheadline(.semibold))
                .foregroundStyle(RoachTheme.text)
                .lineLimit(2)
        }
    }

    private var shellBadges: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                RoachStatusPill(title: status, accent: accent)
                RoachStatusPill(title: secondaryStatus, accent: RoachTheme.cyan)
            }
            VStack(alignment: .leading, spacing: 8) {
                RoachStatusPill(title: status, accent: accent)
                RoachStatusPill(title: secondaryStatus, accent: RoachTheme.cyan)
            }
        }
    }
}

struct StoreGlyph: View {
    let band: String
    let monogram: String
    let accent: Color

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.30), RoachTheme.surface], startPoint: .topLeading,
                        endPoint: .bottomTrailing)
                )
                .frame(width: 62, height: 62)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(
                        accent.opacity(0.34), lineWidth: 1))

            VStack(alignment: .leading, spacing: 1) {
                Text(band)
                    .roachMonoCaps(RoachType.mono(7.5, .bold), size: 7.5, tracking: 0.1)
                    .foregroundStyle(RoachTheme.subduedText)
                Text(monogram)
                    .roachDisplay(20)
                    .foregroundStyle(RoachTheme.text)
            }
            .padding(9)
        }
        .accessibilityHidden(true)
    }
}

struct RoachSectionHeader: View {
    let eyebrow: String
    let title: String
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoachOverline(text: eyebrow)

            Text(title)
                .roachDisplay(24)
                .foregroundStyle(RoachTheme.text)
                .lineLimit(3)
                .minimumScaleFactor(0.84)
                .allowsTightening(true)
                .accessibilityAddTraits(.isHeader)

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(RoachType.body)
                    .foregroundStyle(RoachTheme.subduedText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct RoachMetricTile: View {
    let label: String
    let value: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                RoachDot(accent: accent, size: 6)
                Text(label)
                    .roachMonoCaps(RoachType.label, size: 10.5, tracking: 0.12)
                    .foregroundStyle(RoachTheme.subduedText)
                    .lineLimit(1)
            }
            Text(value)
                .font(RoachType.readout(20))
                .tracking(-0.4)
                .foregroundStyle(RoachTheme.text)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoachCardBackground(cornerRadius: 14, glow: accent, glowStrength: 0.06))
        .overlay(alignment: .bottomLeading) {
            Capsule().fill(accent).frame(width: 28, height: 2).padding(.leading, 12).padding(.bottom, 1)
        }
        .accessibilityElement(children: .combine)
    }
}

struct RoachSignalTile: View {
    let label: String
    let value: String
    let accent: Color
    let systemImage: String
    let subtitle: String?

    init(label: String, value: String, accent: Color, systemImage: String, subtitle: String? = nil) {
        self.label = label
        self.value = value
        self.accent = accent
        self.systemImage = systemImage
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(RoachTheme.ink(for: accent))
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(accent.opacity(0.12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(
                                    accent.opacity(0.3), lineWidth: 1))
                    )
                    .accessibilityHidden(true)

                Text(label)
                    .roachMonoCaps(RoachType.label, size: 10.5, tracking: 0.12)
                    .foregroundStyle(RoachTheme.ink(for: accent))
                    .lineLimit(1)
            }

            Text(value)
                .font(RoachType.headline(.bold))
                .foregroundStyle(RoachTheme.text)
                .lineLimit(2)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(RoachType.caption)
                    .foregroundStyle(RoachTheme.subduedText)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoachCardBackground(cornerRadius: RoachTheme.radiusCard, glow: accent, glowStrength: 0.06))
        .accessibilityElement(children: .combine)
    }
}

struct RoachMetricRow<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                content()
            }
            LazyVGrid(
                columns: [GridItem(.flexible(minimum: 0), spacing: 10), GridItem(.flexible(minimum: 0), spacing: 10)],
                alignment: .leading,
                spacing: 10
            ) {
                content()
            }
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let detail: String
    let actionTitle: String?
    let action: (() -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "tray")
                .font(.system(size: 38, weight: .light))
                .foregroundStyle(RoachTheme.purpleInk)
                .accessibilityHidden(true)

            Text(title)
                .font(RoachType.cardTitle)
                .foregroundStyle(RoachTheme.text)
                .multilineTextAlignment(.center)

            Text(detail)
                .font(RoachType.body)
                .foregroundStyle(RoachTheme.subduedText)
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(RoachButtonStyle(kind: .primary))
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

func formattedBytes(_ bytes: Int64?) -> String {
    guard let bytes else { return "Unknown size" }
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useMB, .useGB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
}

func formattedRelativeDate(_ date: Date?) -> String {
    guard let date else { return "Just now" }
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .short
    return formatter.localizedString(for: date, relativeTo: .now)
}

func roachAccentColor(for accent: String?) -> Color {
    switch (accent ?? "").lowercased() {
    case "green": return RoachTheme.secondary
    case "cyan": return RoachTheme.cyan
    case "blue": return RoachTheme.tertiary
    case "gold": return RoachTheme.warning
    case "violet": return RoachTheme.purpleInk
    case "bronze", "amber": return RoachTheme.amber
    default: return RoachTheme.primary
    }
}
