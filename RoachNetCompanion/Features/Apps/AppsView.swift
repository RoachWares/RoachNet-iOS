import SwiftUI

struct AppsView: View {
    @Bindable var model: CompanionAppModel
    private let columns = [GridItem(.adaptive(minimum: 172), spacing: 14)]

    var body: some View {
        NavigationStack {
            ZStack {
                RoachBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        storeHeader
                        searchField
                        categoryStrip
                        featuredCard
                        sectionIntro
                        savedStrip
                        recentInstallsStrip
                        queuedInstallsStrip
                        spotlightRow
                        catalogGrid
                    }
                    .padding(16)
                    .padding(.bottom, 108)
                }
                .refreshable {
                    try? await model.loadCatalog()
                    if model.connection.isConfigured {
                        await model.refreshAll()
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(item: Binding(
                get: { model.selectedStoreItem },
                set: { model.selectedStoreItem = $0 }
            )) { item in
                AppDetailSheet(model: model, item: item)
            }
        }
    }

    private var storeHeader: some View {
        RoachPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    RoachSectionHeader(
                        eyebrow: "Apps",
                        title: "Bring the useful parts home.",
                        detail: "Maps, courses, models, and references move through the same install handoff the desktop already understands."
                    )

                    Spacer(minLength: 8)

                    Button {
                        model.selectedTab = .chat
                    } label: {
                        Image(systemName: "message.fill")
                            .font(.headline)
                    }
                    .buttonStyle(.bordered)
                    .tint(RoachTheme.secondary)
                }

                compactAppStatus
            }
        }
    }

    private var compactAppStatus: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(minimum: 0), spacing: 10),
                GridItem(.flexible(minimum: 0), spacing: 10),
            ],
            alignment: .leading,
            spacing: 10
        ) {
            CompactStoreStat(
                title: model.connection.isConfigured ? "Bridge ready" : "Pair Mac",
                detail: model.connection.isConfigured ? "Install lane open" : "Needed to install",
                accent: model.connection.isConfigured ? RoachTheme.secondary : RoachTheme.primary
            )
            CompactStoreStat(
                title: model.favoriteItems.isEmpty ? "Saved picks" : "\(model.favoriteItems.count) saved",
                detail: model.favoriteItems.isEmpty ? "Nothing pinned yet" : "Pinned for later",
                accent: model.favoriteItems.isEmpty ? RoachTheme.primary : RoachTheme.tertiary
            )
            CompactStoreStat(
                title: model.queuedInstallCount > 0 ? "\(model.queuedInstallCount) queued" : "Queue clear",
                detail: model.queuedInstallCount > 0 ? "Waiting on desktop" : "Ready to send",
                accent: model.queuedInstallCount > 0 ? RoachTheme.primary : RoachTheme.secondary
            )
            CompactStoreStat(
                title: "\(model.visibleCatalogItems.count) visible",
                detail: model.selectedCategory == "Today" ? "Fast start shelf" : model.selectedCategory,
                accent: RoachTheme.tertiary
            )
        }
    }

    private var appSignals: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(minimum: 0), spacing: 10),
                GridItem(.flexible(minimum: 0), spacing: 10),
            ],
            alignment: .leading,
            spacing: 10
        ) {
            RoachSignalTile(
                label: "Visible",
                value: "\(model.visibleCatalogItems.count)",
                accent: RoachTheme.tertiary,
                systemImage: "square.grid.2x2"
            )
            RoachSignalTile(
                label: "Saved",
                value: "\(model.favoriteItems.count)",
                accent: RoachTheme.primary,
                systemImage: "heart"
            )
            RoachSignalTile(
                label: "Queue",
                value: "\(model.queuedInstallCount)",
                accent: model.queuedInstallCount > 0 ? RoachTheme.secondary : RoachTheme.tertiary,
                systemImage: "tray.full"
            )
            RoachSignalTile(
                label: "Link",
                value: model.connection.isConfigured ? "Ready" : "Pair first",
                accent: model.connection.isConfigured ? RoachTheme.secondary : RoachTheme.primary,
                systemImage: "link"
            )
        }
    }

    private var featuredCard: some View {
        let item = model.featuredItem
        return RoachPanel {
            if let item {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        StoreGlyph(
                            band: item.iconBand ?? "RoachNet",
                            monogram: item.iconMonogram ?? "APP",
                            accent: roachAccentColor(for: item.accent)
                        )

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Today".uppercased())
                                .font(.caption.weight(.bold))
                                .foregroundStyle(RoachTheme.secondary)
                                .tracking(1.2)

                            Text(item.title)
                                .font(.system(size: 20, weight: .black, design: .rounded))
                                .foregroundStyle(RoachTheme.text)
                                .lineLimit(2)

                            Text(item.summary)
                                .font(.subheadline)
                                .foregroundStyle(RoachTheme.subduedText)
                                .lineLimit(2)
                        }

                        Spacer(minLength: 8)

                        favoriteButton(for: item)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            RoachBadge(title: item.category, accent: roachAccentColor(for: item.accent))
                            if let size = item.size {
                                RoachBadge(title: size, accent: RoachTheme.tertiary)
                            }
                            if let status = item.status {
                                RoachBadge(title: status, accent: model.connection.isConfigured ? RoachTheme.secondary : RoachTheme.primary)
                            }
                        }
                        .padding(.vertical, 1)
                    }

                    StoreActionStrip(
                        model: model,
                        item: item,
                        accent: RoachTheme.primary,
                        includesFavorite: false,
                        preferHorizontal: true
                    )
                }
            } else {
                EmptyStateView(
                    title: "Apps catalog",
                    detail: "The companion app pulls the same install lanes that ship from apps.roachnet.org, just closer to hand.",
                    actionTitle: nil,
                    action: nil
                )
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(RoachTheme.secondary)

            TextField("Search apps, maps, courses, or models", text: $model.searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(14)
        .background(RoachTheme.surface.opacity(0.96), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(RoachTheme.border, lineWidth: 1)
        )
    }

    private var categoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(model.categories, id: \.self) { category in
                    Button(category) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            model.selectedCategory = category
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(model.selectedCategory == category ? RoachTheme.primary.opacity(0.26) : RoachTheme.surface.opacity(0.92))
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(
                                        model.selectedCategory == category ? RoachTheme.primary.opacity(0.55) : RoachTheme.border,
                                        lineWidth: 1
                                    )
                            )
                    )
                    .foregroundStyle(model.selectedCategory == category ? Color.white : RoachTheme.subduedText)
                }
            }
        }
    }

    private var sectionIntro: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoachSectionHeader(
                eyebrow: model.selectedCategory,
                title: model.selectedCategory == "Today" ? "The fast start shelf." : "\(model.selectedCategory) brought closer.",
                detail: model.categoryDescription(for: model.selectedCategory)
            )

            HStack(spacing: 8) {
                RoachBadge(title: "\(model.appCount(for: model.selectedCategory)) apps", accent: RoachTheme.secondary)
                RoachBadge(
                    title: model.connection.isConfigured ? "Bridge ready" : "Bridge needed",
                    accent: model.connection.isConfigured ? RoachTheme.tertiary : RoachTheme.primary
                )
                if model.queuedInstallCount > 0 {
                    RoachBadge(title: "\(model.queuedInstallCount) queued", accent: RoachTheme.primary)
                }
            }
        }
    }

    @ViewBuilder
    private var savedStrip: some View {
        if !model.favoriteItems.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Saved")
                    .font(.headline)
                    .foregroundStyle(RoachTheme.text)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(model.favoriteItems.prefix(8)) { item in
                            SpotlightCard(model: model, item: item)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var recentInstallsStrip: some View {
        if !model.recentInstallItems.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Recently sent")
                    .font(.headline)
                    .foregroundStyle(RoachTheme.text)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(model.recentInstallItems.prefix(8)) { item in
                            SpotlightCard(model: model, item: item)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var queuedInstallsStrip: some View {
        if !model.pendingInstallQueue.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Queued for desktop")
                    .font(.headline)
                    .foregroundStyle(RoachTheme.text)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(model.pendingInstallQueue.prefix(8)) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(RoachTheme.text)
                                    .lineLimit(1)
                                Text("Queued \(formattedRelativeDate(item.createdAt))")
                                    .font(.caption)
                                    .foregroundStyle(RoachTheme.subduedText)
                            }
                            .frame(width: 180, alignment: .leading)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(RoachTheme.surface.opacity(0.96))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .strokeBorder(RoachTheme.border, lineWidth: 1)
                                    )
                            )
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var spotlightRow: some View {
        if !model.spotlightItems.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(model.selectedCategory == "Today" ? "Quick installs" : "Spotlight")
                    .font(.headline)
                    .foregroundStyle(RoachTheme.text)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(model.spotlightItems) { item in
                            SpotlightCard(model: model, item: item)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var catalogGrid: some View {
        if model.catalogItems.isEmpty {
            RoachPanel {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(RoachTheme.primary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Loading Apps catalog")
                            .font(.headline)
                            .foregroundStyle(RoachTheme.text)
                        Text("Pulling install metadata and shelf definitions.")
                            .font(.subheadline)
                            .foregroundStyle(RoachTheme.subduedText)
                    }
                    Spacer()
                }
            }
        } else {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(model.visibleCatalogItems) { item in
                    AppCard(model: model, item: item)
                }
            }
        }
    }
}

private struct CompactStoreStat: View {
    let title: String
    let detail: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(accent)
                    .frame(width: 8, height: 8)
                    .shadow(color: accent.opacity(0.35), radius: 8, x: 0, y: 0)

                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(RoachTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Text(detail)
                .font(.caption2)
                .foregroundStyle(RoachTheme.subduedText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(RoachTheme.elevatedSurface.opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(accent.opacity(0.22), lineWidth: 1)
                )
        )
    }
}

private struct SpotlightCard: View {
    @Bindable var model: CompanionAppModel
    let item: StoreAppItem

    var body: some View {
        Button {
            model.selectedStoreItem = item
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    StoreGlyph(
                        band: item.iconBand ?? item.category,
                        monogram: item.iconMonogram ?? "APP",
                        accent: roachAccentColor(for: item.accent)
                    )

                    Spacer()

                    if let size = item.size {
                        Text(size)
                            .font(.caption2)
                            .foregroundStyle(RoachTheme.subduedText)
                    }
                }

                Text(item.title)
                    .font(.headline)
                    .foregroundStyle(RoachTheme.text)
                    .lineLimit(2)

                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(RoachTheme.subduedText)
                    .lineLimit(2)
            }
            .frame(width: 196, alignment: .leading)
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(RoachTheme.surface.opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(RoachTheme.border, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct AppCard: View {
    @Bindable var model: CompanionAppModel
    let item: StoreAppItem

    var body: some View {
        RoachPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    StoreGlyph(
                        band: item.iconBand ?? item.category,
                        monogram: item.iconMonogram ?? "APP",
                        accent: roachAccentColor(for: item.accent)
                    )
                    Spacer()
                    if let size = item.size {
                        Text(size)
                            .font(.caption)
                            .foregroundStyle(RoachTheme.subduedText)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.headline)
                        .foregroundStyle(RoachTheme.text)
                        .lineLimit(2)

                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(RoachTheme.subduedText)
                        .lineLimit(2)

                    Text(item.summary)
                        .font(.subheadline)
                        .foregroundStyle(RoachTheme.subduedText)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Text(item.category)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(RoachTheme.secondary)
                    if let status = item.status {
                        Text(status)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(roachAccentColor(for: item.accent))
                    }
                }

                Spacer(minLength: 0)

                StoreActionStrip(
                    model: model,
                    item: item,
                    accent: roachAccentColor(for: item.accent)
                )
            }
            .frame(maxWidth: .infinity, minHeight: 246, alignment: .topLeading)
        }
    }
}

private struct AppDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: CompanionAppModel
    let item: StoreAppItem

    var body: some View {
        NavigationStack {
            ZStack {
                RoachBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        RoachPanel {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    StoreGlyph(
                                        band: item.iconBand ?? item.category,
                                        monogram: item.iconMonogram ?? "APP",
                                        accent: roachAccentColor(for: item.accent)
                                    )
                                    Spacer()
                                    Button {
                                        model.toggleFavorite(item)
                                    } label: {
                                        Image(systemName: model.isFavorite(item) ? "heart.fill" : "heart")
                                            .font(.headline)
                                    }
                                    .buttonStyle(.bordered)
                                    .tint(model.isFavorite(item) ? RoachTheme.primary : RoachTheme.secondary)
                                    if let source = item.source {
                                        RoachBadge(title: source, accent: roachAccentColor(for: item.accent))
                                    }
                                }

                                RoachSectionHeader(
                                    eyebrow: item.category,
                                    title: item.title,
                                    detail: item.summary
                                )

                                HStack(spacing: 10) {
                                    if let size = item.size {
                                        RoachMetricTile(label: "Size", value: size, accent: RoachTheme.secondary)
                                    }

                                    if let status = item.status {
                                        RoachMetricTile(label: "Shelf", value: status, accent: roachAccentColor(for: item.accent))
                                    }
                                }

                                if !item.includes.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Inside")
                                            .font(.headline)
                                            .foregroundStyle(RoachTheme.text)

                                        ForEach(item.includes, id: \.self) { line in
                                            Text("• \(line)")
                                                .foregroundStyle(RoachTheme.subduedText)
                                        }
                                    }
                                }

                                Button(displayInstallLabel(for: item)) {
                                    Task { await model.install(item) }
                                }
                                .font(.subheadline.weight(.black))
                                .foregroundStyle(Color.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    roachAccentColor(for: item.accent).opacity(0.96),
                                                    RoachTheme.primary.opacity(0.72),
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                )
                                .overlay(
                                    Capsule(style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                                )
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle(item.title)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct StoreActionStrip: View {
    @Bindable var model: CompanionAppModel
    let item: StoreAppItem
    let accent: Color
    var includesFavorite = true
    var preferHorizontal = false

    private var isInstalling: Bool {
        model.installingItemIDs.contains(item.id)
    }

    var body: some View {
        Group {
            if preferHorizontal {
                ViewThatFits(in: .horizontal) {
                    horizontalLayout
                    verticalLayout
                }
            } else {
                verticalLayout
            }
        }
    }

    private var horizontalLayout: some View {
        HStack(spacing: 10) {
            installButton
            detailsButton
            if includesFavorite {
                favoriteButton
                    .frame(width: 46)
            }
        }
    }

    private var verticalLayout: some View {
        VStack(spacing: 8) {
            installButton

            HStack(spacing: 8) {
                detailsButton
                if includesFavorite {
                    favoriteButton
                        .frame(width: 46)
                }
            }
        }
    }

    private var installButton: some View {
        Button {
            Task { await model.install(item) }
        } label: {
            Label(isInstalling ? "Installing…" : displayInstallLabel(for: item), systemImage: isInstalling ? "hourglass" : "square.and.arrow.down")
                .font(.caption.weight(.black))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [accent.opacity(0.95), accent.opacity(0.62)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    Capsule(style: .continuous)
                        .strokeBorder(Color.white.opacity(0.16), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.white)
        .disabled(isInstalling)
        .opacity(isInstalling ? 0.72 : 1)
    }

    private var detailsButton: some View {
        Button("Details") {
            model.selectedStoreItem = item
        }
        .font(.caption.weight(.bold))
        .lineLimit(1)
        .minimumScaleFactor(0.78)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Capsule(style: .continuous)
                .fill(RoachTheme.elevatedSurface.opacity(0.95))
        )
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(RoachTheme.secondary.opacity(0.32), lineWidth: 1)
        )
        .foregroundStyle(RoachTheme.text)
        .buttonStyle(.plain)
    }

    private var favoriteButton: some View {
        Button {
            model.toggleFavorite(item)
        } label: {
            Image(systemName: model.isFavorite(item) ? "heart.fill" : "heart")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .frame(height: 38)
        .background(
            Circle()
                .fill((model.isFavorite(item) ? RoachTheme.primary : RoachTheme.elevatedSurface).opacity(0.94))
        )
        .overlay(
            Circle()
                .strokeBorder((model.isFavorite(item) ? RoachTheme.primary : RoachTheme.secondary).opacity(0.34), lineWidth: 1)
        )
        .foregroundStyle(model.isFavorite(item) ? Color.white : RoachTheme.text)
        .buttonStyle(.plain)
    }
}

private func displayInstallLabel(for item: StoreAppItem) -> String {
    guard let installLabel = item.installLabel, !installLabel.isEmpty else {
        return "Install"
    }
    return installLabel.contains("RoachNet") ? "Install" : installLabel
}

private extension AppsView {
    func favoriteButton(for item: StoreAppItem) -> some View {
        Button {
            model.toggleFavorite(item)
        } label: {
            Image(systemName: model.isFavorite(item) ? "heart.fill" : "heart")
                .font(.headline)
                .foregroundStyle(Color.white)
        }
        .buttonStyle(.bordered)
        .tint(model.isFavorite(item) ? RoachTheme.primary : RoachTheme.secondary)
    }
}
