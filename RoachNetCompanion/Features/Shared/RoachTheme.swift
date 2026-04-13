import SwiftUI

enum RoachTheme {
    static let background = Color(red: 0.03, green: 0.04, blue: 0.08)
    static let backgroundRaised = Color(red: 0.05, green: 0.06, blue: 0.11)
    static let surface = Color(red: 0.07, green: 0.08, blue: 0.12)
    static let elevatedSurface = Color(red: 0.10, green: 0.11, blue: 0.16)
    static let glassHighlight = Color.white.opacity(0.10)
    static let elevatedBorder = Color.white.opacity(0.14)
    static let border = Color.white.opacity(0.08)
    static let primary = Color(red: 0.89, green: 0.32, blue: 0.70)
    static let secondary = Color(red: 0.33, green: 0.96, blue: 0.71)
    static let tertiary = Color(red: 0.36, green: 0.59, blue: 1.0)
    static let text = Color.white.opacity(0.94)
    static let subduedText = Color.white.opacity(0.66)
}

private struct RoachAmbientOrb: View {
    let accent: Color
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(accent.opacity(0.22))
            .frame(width: size, height: size)
            .blur(radius: size * 0.28)
            .overlay(
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color.white.opacity(0.42),
                                Color.white.opacity(0.06),
                                Color.clear,
                            ],
                            center: .topLeading,
                            startRadius: 2,
                            endRadius: size * 0.46
                        )
                    )
                    .blur(radius: size * 0.06)
            )
    }
}

struct RoachBackdrop: View {
    @State private var sweep = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    RoachTheme.background,
                    RoachTheme.backgroundRaised,
                    Color(red: 0.05, green: 0.03, blue: 0.08),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    RoachTheme.primary.opacity(0.24),
                    .clear,
                ],
                center: .topTrailing,
                startRadius: 12,
                endRadius: 320
            )

            RadialGradient(
                colors: [
                    RoachTheme.secondary.opacity(0.18),
                    .clear,
                ],
                center: .bottomLeading,
                startRadius: 12,
                endRadius: 300
            )

            GeometryReader { proxy in
                Path { path in
                    let step: CGFloat = 28
                    stride(from: CGFloat.zero, through: proxy.size.width, by: step).forEach { x in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: proxy.size.height))
                    }
                    stride(from: CGFloat.zero, through: proxy.size.height, by: step).forEach { y in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: proxy.size.width, y: y))
                    }
                }
                .stroke(Color.white.opacity(0.025), lineWidth: 0.5)
            }

            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 120, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.clear,
                                RoachTheme.secondary.opacity(0.16),
                                RoachTheme.tertiary.opacity(0.12),
                                Color.clear,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: proxy.size.width * 0.74, height: 180)
                    .blur(radius: 44)
                    .rotationEffect(.degrees(-16))
                    .offset(
                        x: sweep ? proxy.size.width * 0.26 : -proxy.size.width * 0.36,
                        y: sweep ? proxy.size.height * 0.10 : -proxy.size.height * 0.12
                    )
                    .opacity(0.42)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 16).repeatForever(autoreverses: true)) {
                sweep = true
            }
        }
    }
}

private struct RoachGlassChrome: View {
    let accent: Color
    let cornerRadius: CGFloat
    @State private var drift = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.08),
                                accent.opacity(0.22),
                                RoachTheme.elevatedBorder,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )

                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                accent.opacity(0.16),
                                Color.clear,
                                RoachTheme.tertiary.opacity(0.08),
                                Color.clear,
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: proxy.size.width * 0.56, height: max(88, proxy.size.height * 0.44))
                    .blur(radius: 28)
                    .rotationEffect(.degrees(-16))
                    .offset(
                        x: drift ? proxy.size.width * 0.34 : -proxy.size.width * 0.28,
                        y: drift ? proxy.size.height * 0.12 : -proxy.size.height * 0.10
                    )
                    .opacity(0.46)

                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.48), RoachTheme.primary.opacity(0.22), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: min(proxy.size.width * 0.42, 180), height: 3)
                    .padding(.leading, 16)
                    .padding(.top, 12)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }
}

struct RoachPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                RoachTheme.surface.opacity(0.98),
                                RoachTheme.elevatedSurface.opacity(0.95),
                                Color.black.opacity(0.12),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        RoachTheme.primary.opacity(0.24),
                                        Color.clear,
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .center
                                )
                            )
                            .mask(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                            )
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        RoachTheme.glassHighlight,
                                        Color.clear,
                                        Color.clear,
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blendMode(.screen)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(RoachTheme.elevatedBorder, lineWidth: 1)
                    )
                    .overlay(
                        RoachGlassChrome(accent: RoachTheme.secondary, cornerRadius: 22)
                    )
                    .shadow(color: Color.black.opacity(0.24), radius: 22, x: 0, y: 14)
                    .shadow(color: RoachTheme.primary.opacity(0.05), radius: 32, x: 0, y: 18)
            )
    }
}

struct RoachHeroPanel<Content: View>: View {
    let accent: Color
    let content: Content
    @State private var drift = false

    init(accent: Color = RoachTheme.primary, @ViewBuilder content: () -> Content) {
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                RoachTheme.surface.opacity(0.98),
                                RoachTheme.elevatedSurface.opacity(0.96),
                                Color.black.opacity(0.14),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(alignment: .topLeading) {
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        accent.opacity(0.24),
                                        Color.clear,
                                        RoachTheme.secondary.opacity(0.06),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.10),
                                        accent.opacity(0.28),
                                        Color.white.opacity(0.06),
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .overlay {
                        RoachGlassChrome(accent: accent, cornerRadius: 28)
                    }
                    .overlay(alignment: .topTrailing) {
                        RoachAmbientOrb(accent: accent, size: 132)
                            .offset(x: drift ? 10 : -20, y: drift ? -12 : 16)
                            .opacity(0.82)
                    }
                    .overlay(alignment: .bottomLeading) {
                        RoachAmbientOrb(accent: RoachTheme.secondary, size: 94)
                            .offset(x: drift ? -14 : 10, y: drift ? 18 : 42)
                            .opacity(0.44)
                    }
                    .shadow(color: Color.black.opacity(0.26), radius: 28, x: 0, y: 16)
                    .shadow(color: accent.opacity(0.08), radius: 34, x: 0, y: 20)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 7.2).repeatForever(autoreverses: true)) {
                    drift = true
                }
            }
    }
}

struct RoachBadge: View {
    let title: String
    let accent: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.24), accent.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(accent.opacity(0.45), lineWidth: 1)
                    )
            )
    }
}

struct RoachStatusPill: View {
    let title: String
    let accent: Color

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.18))
                    .frame(width: 18, height: 18)

                Circle()
                    .fill(accent)
                    .frame(width: 8, height: 8)
                    .shadow(color: accent.opacity(0.42), radius: 8, x: 0, y: 0)
            }

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RoachTheme.text)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            RoachTheme.elevatedSurface.opacity(0.94),
                            RoachTheme.surface.opacity(0.90),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(accent.opacity(0.20), lineWidth: 1)
                )
        )
    }
}

struct RoachActionPill: View {
    let title: String
    let systemImage: String
    let accent: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.white)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(accent.opacity(0.24))
                        .overlay(
                            Circle()
                                .strokeBorder(accent.opacity(0.34), lineWidth: 1)
                        )
                )

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(RoachTheme.text)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            Capsule(style: .continuous)
                .fill(RoachTheme.elevatedSurface.opacity(0.9))
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(accent.opacity(0.16), lineWidth: 1)
                )
        )
    }
}

struct RoachTabBarItem: Identifiable {
    let tab: CompanionTab
    let title: String
    let systemImage: String
    let accent: Color

    var id: CompanionTab { tab }
}

struct RoachFloatingTabBar: View {
    @Binding var selection: CompanionTab
    let items: [RoachTabBarItem]
    @Namespace private var selectionMotion
    @State private var drift = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(items) { item in
                Button {
                    withAnimation(.spring(response: 0.34, dampingFraction: 0.84)) {
                        selection = item.tab
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: item.systemImage)
                            .font(.system(size: 14, weight: .semibold))
                            .frame(width: 18, height: 18)

                        if selection == item.tab {
                            Text(item.title)
                                .font(.caption.weight(.bold))
                                .lineLimit(1)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .foregroundStyle(selection == item.tab ? Color.white : RoachTheme.subduedText)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, selection == item.tab ? 12 : 9)
                    .padding(.vertical, 11)
                    .background {
                        Capsule(style: .continuous)
                            .fill(
                                selection == item.tab
                                    ? item.accent.opacity(0.22)
                                    : RoachTheme.elevatedSurface.opacity(0.58)
                            )
                            .overlay {
                                Capsule(style: .continuous)
                                    .strokeBorder(
                                        selection == item.tab
                                            ? item.accent.opacity(0.42)
                                            : Color.white.opacity(0.06),
                                        lineWidth: 1
                                    )
                            }
                            .overlay {
                                if selection == item.tab {
                                    Capsule(style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    item.accent.opacity(0.22),
                                                    Color.clear,
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .matchedGeometryEffect(id: "roach-tab-pill", in: selectionMotion)
                                }
                            }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    RoachTheme.surface.opacity(0.90),
                                    RoachTheme.elevatedSurface.opacity(0.86),
                                    Color.black.opacity(0.08),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [RoachTheme.glassHighlight, Color.clear, Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.screen)
                )
                .overlay(alignment: .topTrailing) {
                    RoachAmbientOrb(accent: items.first(where: { $0.tab == selection })?.accent ?? RoachTheme.secondary, size: 76)
                        .offset(x: drift ? 4 : -10, y: drift ? -8 : 10)
                        .opacity(0.48)
                }
                .overlay(
                    RoachGlassChrome(accent: RoachTheme.secondary, cornerRadius: 26)
                )
                .shadow(color: Color.black.opacity(0.26), radius: 28, x: 0, y: 16)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 6.8).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }
}

struct RoachShellDock: View {
    let title: String
    let detail: String
    let accent: Color
    let status: String
    let secondaryStatus: String
    @State private var drift = false

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
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    RoachTheme.surface.opacity(0.92),
                                    RoachTheme.elevatedSurface.opacity(0.90),
                                    Color.black.opacity(0.08),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.10),
                                    accent.opacity(0.24),
                                    Color.white.opacity(0.05),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .overlay {
                    RoachGlassChrome(accent: accent, cornerRadius: 24)
                }
                .overlay(alignment: .topLeading) {
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.92), RoachTheme.secondary.opacity(0.22), Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: 110, height: 3)
                        .padding(.top, 12)
                        .padding(.leading, 16)
                }
                .overlay(alignment: .topTrailing) {
                    RoachAmbientOrb(accent: accent, size: 88)
                        .offset(x: drift ? 8 : -12, y: drift ? -6 : 12)
                        .opacity(0.7)
                }
                .shadow(color: Color.black.opacity(0.22), radius: 24, x: 0, y: 14)
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 6.4).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }

    private var shellMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.88), accent.opacity(0.42), RoachTheme.elevatedSurface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 50, height: 50)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )

            Image(systemName: "point.3.connected.trianglepath.dotted")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color.white)
        }
    }

    private var shellCopy: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(accent.opacity(0.94))

            Text(detail)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(RoachTheme.text)
                .lineLimit(2)
        }
    }

    private var shellBadges: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                RoachStatusPill(title: status, accent: accent)
                RoachStatusPill(title: secondaryStatus, accent: RoachTheme.tertiary)
            }

            VStack(alignment: .leading, spacing: 8) {
                RoachStatusPill(title: status, accent: accent)
                RoachStatusPill(title: secondaryStatus, accent: RoachTheme.tertiary)
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
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [accent.opacity(0.92), accent.opacity(0.42), RoachTheme.elevatedSurface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 62, height: 62)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                )
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(Color.white.opacity(0.22))
                        .frame(width: 12, height: 12)
                        .padding(8)
                }

            VStack(alignment: .leading, spacing: 1) {
                Text(band.uppercased())
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.76))
                Text(monogram)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundStyle(Color.white)
            }
            .padding(10)
        }
    }
}

struct RoachSectionHeader: View {
    let eyebrow: String
    let title: String
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow.uppercased())
                .font(.caption.weight(.bold))
                .foregroundStyle(RoachTheme.secondary)
                .tracking(1.2)

            Text(title)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(RoachTheme.text)
                .tracking(-0.4)
                .lineLimit(2)
                .minimumScaleFactor(0.84)
                .allowsTightening(true)

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.subheadline)
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
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent, accent.opacity(0.24)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: 28, height: 3)

                Text(label.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(accent.opacity(0.92))
                    .tracking(1)
            }

            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(RoachTheme.text)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(RoachTheme.elevatedSurface.opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(accent.opacity(0.18), lineWidth: 1)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [RoachTheme.glassHighlight.opacity(0.8), Color.clear, Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.screen)
                )
                .overlay(
                    RoachGlassChrome(accent: accent, cornerRadius: 18)
                )
        )
    }
}

struct RoachSignalTile: View {
    let label: String
    let value: String
    let accent: Color
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.16))
                        .frame(width: 34, height: 34)

                    Image(systemName: systemImage)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.white)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(accent.opacity(0.22))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .strokeBorder(accent.opacity(0.34), lineWidth: 1)
                                )
                        )
                }

                Text(label.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(0.9)
                    .foregroundStyle(accent.opacity(0.94))
                    .lineLimit(1)
            }

            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(RoachTheme.text)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(RoachTheme.elevatedSurface.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(accent.opacity(0.18), lineWidth: 1)
                )
                .overlay(
                    RoachGlassChrome(accent: accent, cornerRadius: 18)
                )
        )
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
                columns: [
                    GridItem(.flexible(minimum: 0), spacing: 10),
                    GridItem(.flexible(minimum: 0), spacing: 10),
                ],
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
        VStack(spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 42))
                .foregroundStyle(RoachTheme.primary)

            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(RoachTheme.text)

            Text(detail)
                .font(.subheadline)
                .foregroundStyle(RoachTheme.subduedText)
                .multilineTextAlignment(.center)

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .tint(RoachTheme.primary)
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
    case "cyan": return Color.cyan
    case "blue": return RoachTheme.tertiary
    case "gold": return Color.yellow
    case "violet": return Color.purple
    case "bronze": return Color.orange
    default: return RoachTheme.primary
    }
}
