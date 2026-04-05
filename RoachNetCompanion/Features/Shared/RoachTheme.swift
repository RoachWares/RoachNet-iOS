import SwiftUI

enum RoachTheme {
    static let background = Color(red: 0.03, green: 0.04, blue: 0.08)
    static let surface = Color(red: 0.07, green: 0.08, blue: 0.12)
    static let elevatedSurface = Color(red: 0.10, green: 0.11, blue: 0.16)
    static let elevatedBorder = Color.white.opacity(0.14)
    static let border = Color.white.opacity(0.08)
    static let primary = Color(red: 0.89, green: 0.32, blue: 0.70)
    static let secondary = Color(red: 0.33, green: 0.96, blue: 0.71)
    static let tertiary = Color(red: 0.36, green: 0.59, blue: 1.0)
    static let text = Color.white.opacity(0.94)
    static let subduedText = Color.white.opacity(0.66)
}

struct RoachBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    RoachTheme.background,
                    Color(red: 0.04, green: 0.06, blue: 0.10),
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
        }
        .ignoresSafeArea()
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
                                RoachTheme.elevatedSurface.opacity(0.94),
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
                            .strokeBorder(RoachTheme.elevatedBorder, lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.24), radius: 22, x: 0, y: 14)
            )
    }
}

struct RoachBadge: View {
    let title: String
    let accent: Color

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule(style: .continuous)
                    .fill(accent.opacity(0.22))
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(accent.opacity(0.45), lineWidth: 1)
                    )
            )
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
                .font(.title3.weight(.black))
                .foregroundStyle(RoachTheme.text)

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(RoachTheme.subduedText)
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
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(accent.opacity(0.92))
                .tracking(1)

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
        )
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
