import SwiftUI

struct VaultView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Bindable var model: CompanionAppModel

    private var shelfCardWidth: CGFloat {
        horizontalSizeClass == .compact ? 228 : 268
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RoachBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        vaultHeader
                        if let vault = model.vault {
                            summaryPanel(vault)
                            notesPanel(vault)
                            knowledgePanel(vault)
                        } else if model.connection.isConfigured, model.isBootstrapping {
                            RoachPanel {
                                HStack(spacing: 12) {
                                    ProgressView()
                                        .tint(RoachTheme.primary)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Loading Vault")
                                            .font(.headline)
                                            .foregroundStyle(RoachTheme.text)
                                        Text("Pulling RoachBrain, files, atlas packs, and study shelves from the paired Mac.")
                                            .font(.subheadline)
                                            .foregroundStyle(RoachTheme.subduedText)
                                    }
                                    Spacer()
                                }
                            }
                        } else {
                            EmptyStateView(
                                title: "Bring the shelf forward",
                                detail: "Pair the Mac to browse RoachBrain, files, captures, atlas packs, and study shelves from the phone.",
                                actionTitle: "Open connection"
                            ) {
                                model.settingsPresented = true
                            }
                        }
                    }
                    .padding(16)
                }
                .refreshable {
                    await model.refreshAll()
                }
            }
            .navigationBarHidden(true)
        }
    }

    private var vaultHeader: some View {
        RoachPanel {
            VStack(alignment: .leading, spacing: 12) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        RoachShellDock(
                            title: "Vault",
                            detail: model.connection.isConfigured
                                ? "The paired shelf stays readable from the phone without pretending the phone is the desktop."
                                : "Pair the Mac to bring the shelf forward.",
                            accent: RoachTheme.secondary,
                            status: model.connection.isConfigured ? "Shelf linked" : "Shelf local",
                            secondaryStatus: model.runtime?.roachSync?.enabled == true ? "RoachSync armed" : "RoachSync off"
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            model.settingsPresented = true
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                                .font(.headline)
                        }
                        .buttonStyle(.bordered)
                        .tint(RoachTheme.secondary)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        RoachShellDock(
                            title: "Vault",
                            detail: model.connection.isConfigured
                                ? "The paired shelf stays readable from the phone without pretending the phone is the desktop."
                                : "Pair the Mac to bring the shelf forward.",
                            accent: RoachTheme.secondary,
                            status: model.connection.isConfigured ? "Shelf linked" : "Shelf local",
                            secondaryStatus: model.runtime?.roachSync?.enabled == true ? "RoachSync armed" : "RoachSync off"
                        )

                        Button {
                            model.settingsPresented = true
                        } label: {
                            Label("Connection settings", systemImage: "slider.horizontal.3")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(RoachTheme.secondary)
                    }
                }

                if let lastRefreshAt = model.lastRefreshAt {
                    Text("Last sync \(formattedRelativeDate(lastRefreshAt))")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RoachTheme.subduedText)
                }

                vaultPills
                vaultSignals
            }
        }
    }

    private var vaultPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                RoachStatusPill(
                    title: model.connection.isConfigured ? "Paired vault" : "Local cache",
                    accent: model.connection.isConfigured ? RoachTheme.secondary : RoachTheme.primary
                )
                RoachStatusPill(
                    title: model.runtime?.account?.linked == true ? "Account sync" : "Account local",
                    accent: model.runtime?.account?.linked == true ? RoachTheme.tertiary : RoachTheme.primary
                )
                RoachStatusPill(
                    title: model.runtime?.roachSync?.enabled == true ? "RoachSync armed" : "RoachSync off",
                    accent: model.runtime?.roachSync?.enabled == true ? RoachTheme.secondary : RoachTheme.primary
                )
            }
            .padding(.vertical, 1)
        }
    }

    private var vaultSignals: some View {
        let roachBrainCount = model.vault?.roachBrain.count ?? 0
        let knowledgeCount = model.vault?.knowledgeFiles.count ?? 0
        let archiveCount = model.vault?.siteArchives.count ?? 0
        let shelfCount =
            (model.vault?.atlasShelves.count ?? 0) +
            (model.vault?.studyShelves.count ?? 0) +
            (model.vault?.referenceShelves.count ?? 0)

        return LazyVGrid(
            columns: [
                GridItem(.flexible(minimum: 0), spacing: 10),
                GridItem(.flexible(minimum: 0), spacing: 10),
            ],
            alignment: .leading,
            spacing: 10
        ) {
            RoachSignalTile(
                label: "RoachBrain",
                value: "\(roachBrainCount)",
                accent: RoachTheme.primary,
                systemImage: "brain.head.profile"
            )
            RoachSignalTile(
                label: "Files",
                value: "\(knowledgeCount)",
                accent: RoachTheme.secondary,
                systemImage: "doc.text"
            )
            RoachSignalTile(
                label: "Captures",
                value: "\(archiveCount)",
                accent: RoachTheme.tertiary,
                systemImage: "shippingbox"
            )
            RoachSignalTile(
                label: "Shelves",
                value: "\(shelfCount)",
                accent: model.connection.isConfigured ? RoachTheme.secondary : RoachTheme.primary,
                systemImage: "books.vertical.fill"
            )
        }
    }

    private func summaryPanel(_ vault: CompanionVaultSummary) -> some View {
        RoachPanel {
            VStack(alignment: .leading, spacing: 12) {
                RoachSectionHeader(
                    eyebrow: "Vault",
                    title: "The Mac shelf, carried forward.",
                    detail: "RoachBrain, files, captures, atlas packs, and study shelves stay close without turning the phone into a second desktop."
                )

                RoachMetricRow {
                    RoachMetricTile(label: "RoachBrain", value: "\(vault.roachBrain.count)", accent: RoachTheme.primary)
                    RoachMetricTile(label: "Files", value: "\(vault.knowledgeFiles.count)", accent: RoachTheme.secondary)
                    RoachMetricTile(label: "Captures", value: "\(vault.siteArchives.count)", accent: RoachTheme.tertiary)
                    RoachMetricTile(
                        label: "Shelves",
                        value: "\(vault.atlasShelves.count + vault.studyShelves.count + vault.referenceShelves.count)",
                        accent: RoachTheme.secondary
                    )
                }

                HStack(spacing: 10) {
                    RoachActionPill(title: "RoachBrain", systemImage: "brain.head.profile", accent: RoachTheme.primary)
                    RoachActionPill(title: "Atlas", systemImage: "map.fill", accent: RoachTheme.secondary)
                    RoachActionPill(title: "Captured Web", systemImage: "shippingbox", accent: RoachTheme.tertiary)
                }

                if let lastRefreshAt = model.lastRefreshAt {
                    Text("Last sync \(formattedRelativeDate(lastRefreshAt))")
                        .font(.caption)
                        .foregroundStyle(RoachTheme.subduedText)
                }
            }
        }
    }

    private func notesPanel(_ vault: CompanionVaultSummary) -> some View {
        RoachPanel {
            VStack(alignment: .leading, spacing: 12) {
                RoachSectionHeader(
                    eyebrow: "RoachBrain",
                    title: "Pinned memory and recent notes.",
                    detail: vault.roachBrain.isEmpty ? "No captured memory yet." : nil
                )

                if vault.roachBrain.isEmpty {
                    Text("No captured memory yet.")
                        .font(.subheadline)
                        .foregroundStyle(RoachTheme.subduedText)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(vault.roachBrain.prefix(6)) { memory in
                                CompanionVaultShelfCard(
                                    eyebrow: memory.pinned ? "Pinned memory" : "RoachBrain",
                                    title: memory.title,
                                    detail: memory.summary,
                                    systemImage: memory.pinned ? "pin.fill" : "brain.head.profile",
                                    accent: memory.pinned ? RoachTheme.primary : RoachTheme.secondary,
                                    tags: Array(memory.tags.prefix(3))
                                )
                                .frame(width: shelfCardWidth)
                            }
                        }
                    }
                }
            }
        }
    }

    private func knowledgePanel(_ vault: CompanionVaultSummary) -> some View {
        let hasShelfContent =
            !vault.knowledgeFiles.isEmpty ||
            !vault.siteArchives.isEmpty ||
            !vault.atlasShelves.isEmpty ||
            !vault.studyShelves.isEmpty ||
            !vault.referenceShelves.isEmpty

        return RoachPanel {
            VStack(alignment: .leading, spacing: 12) {
                RoachSectionHeader(
                    eyebrow: "Shelf",
                    title: "One living shelf, not six lanes.",
                    detail: hasShelfContent ? "Files, captures, atlas packs, study shelves, and offline references stay stacked together." : "No shelf items yet."
                )

                if !vault.atlasShelves.isEmpty {
                    vaultShelfSection(title: "Atlas shelf", items: vault.atlasShelves, accent: RoachTheme.secondary)
                }

                if !vault.studyShelves.isEmpty {
                    vaultShelfSection(title: "Study shelf", items: vault.studyShelves, accent: RoachTheme.primary)
                }

                if !vault.referenceShelves.isEmpty {
                    vaultShelfSection(title: "Reference shelf", items: vault.referenceShelves, accent: RoachTheme.tertiary)
                }

                if !hasShelfContent {
                    Text("No shelf items yet.")
                        .font(.subheadline)
                        .foregroundStyle(RoachTheme.subduedText)
                } else {
                    if !vault.knowledgeFiles.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Docs and media")
                                .font(.headline)
                                .foregroundStyle(RoachTheme.text)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(vault.knowledgeFiles.prefix(8), id: \.self) { file in
                                        CompanionVaultShelfCard(
                                            eyebrow: fileShelfEyebrow(for: file),
                                            title: URL(fileURLWithPath: file).lastPathComponent,
                                            detail: file,
                                            systemImage: fileShelfIcon(for: file),
                                            accent: fileShelfAccent(for: file),
                                            tags: [fileShelfAction(for: file), "Vault lane"]
                                        )
                                        .frame(width: shelfCardWidth)
                                    }
                                }
                            }
                        }
                    }

                    if !vault.siteArchives.isEmpty {
                        if !vault.knowledgeFiles.isEmpty {
                            Divider()
                                .overlay(RoachTheme.border)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Captured web")
                                .font(.headline)
                                .foregroundStyle(RoachTheme.text)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(vault.siteArchives.prefix(6)) { archive in
                                        CompanionVaultShelfCard(
                                            eyebrow: "Captured web",
                                            title: archive.title ?? archive.slug,
                                            detail: archive.note ?? archive.sourceUrl ?? "Offline capture ready.",
                                            systemImage: "globe.badge.chevron.backward",
                                            accent: RoachTheme.tertiary,
                                            tags: ["Offline shelf", "Vault lane"]
                                        )
                                        .frame(width: shelfCardWidth)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private func vaultShelfSection(title: String, items: [CompanionVaultShelfItem], accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(RoachTheme.text)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(items) { item in
                        Button {
                            if let routePath = item.routePath {
                                model.openPairedRoute(routePath)
                            }
                        } label: {
                            CompanionVaultShelfCard(
                                eyebrow: shelfEyebrow(for: item),
                                title: item.title,
                                detail: item.detail,
                                systemImage: shelfIcon(for: item),
                                accent: accent,
                                tags: [item.status] + (item.actionLabel.map { [$0] } ?? [])
                            )
                            .frame(width: shelfCardWidth)
                        }
                        .buttonStyle(.plain)
                        .disabled(item.routePath == nil || !model.connection.isConfigured)
                    }
                }
            }
        }
    }

    private func shelfEyebrow(for item: CompanionVaultShelfItem) -> String {
        switch item.kind {
        case "atlas":
            return "Atlas"
        case "study":
            return "Study"
        case "reference":
            return "Reference"
        default:
            return "Shelf"
        }
    }

    private func shelfIcon(for item: CompanionVaultShelfItem) -> String {
        switch item.kind {
        case "atlas":
            return "map.fill"
        case "study":
            return "graduationcap.fill"
        case "reference":
            return "books.vertical.fill"
        default:
            return "shippingbox.fill"
        }
    }

    private func fileShelfEyebrow(for file: String) -> String {
        switch URL(fileURLWithPath: file).pathExtension.lowercased() {
        case "md", "markdown":
            return "Markdown"
        case "pdf", "epub":
            return "Reader"
        case "mp3", "m4a", "wav", "flac", "ogg":
            return "Audio"
        case "mp4", "m4v", "mov", "webm", "mkv":
            return "Video"
        default:
            return "File"
        }
    }

    private func fileShelfIcon(for file: String) -> String {
        switch URL(fileURLWithPath: file).pathExtension.lowercased() {
        case "md", "markdown":
            return "note.text"
        case "pdf", "epub":
            return "books.vertical.fill"
        case "mp3", "m4a", "wav", "flac", "ogg":
            return "waveform"
        case "mp4", "m4v", "mov", "webm", "mkv":
            return "film.fill"
        default:
            return "doc.fill"
        }
    }

    private func fileShelfAccent(for file: String) -> Color {
        switch URL(fileURLWithPath: file).pathExtension.lowercased() {
        case "pdf", "epub":
            return RoachTheme.tertiary
        case "mp3", "m4a", "wav", "flac", "ogg":
            return RoachTheme.secondary
        case "mp4", "m4v", "mov", "webm", "mkv":
            return RoachTheme.primary
        default:
            return RoachTheme.secondary
        }
    }

    private func fileShelfAction(for file: String) -> String {
        switch URL(fileURLWithPath: file).pathExtension.lowercased() {
        case "pdf", "epub":
            return "Reader lane"
        case "mp3", "m4a", "wav", "flac", "ogg":
            return "Play on Mac"
        case "mp4", "m4v", "mov", "webm", "mkv":
            return "Watch on Mac"
        case "md", "markdown":
            return "Open note"
        default:
            return "Open file"
        }
    }
}

private struct CompanionVaultShelfCard: View {
    let eyebrow: String
    let title: String
    let detail: String
    let systemImage: String
    let accent: Color
    let tags: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(accent.opacity(0.16))
                        .frame(width: 52, height: 52)

                    Image(systemName: systemImage)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(accent)
                }

                Spacer(minLength: 0)

                RoachBadge(title: eyebrow, accent: accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(RoachTheme.text)
                    .lineLimit(2)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(RoachTheme.subduedText)
                    .lineLimit(4)
                    .multilineTextAlignment(.leading)
            }

            if !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            RoachBadge(title: tag, accent: accent)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(RoachTheme.elevatedSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(accent.opacity(0.22), lineWidth: 1)
                )
        )
    }
}
