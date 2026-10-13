import SwiftUI

struct AppsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Bindable var model: CompanionAppModel
    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 160 : 214), spacing: 14)]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                RoachBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        storeHeader
                        if model.catalogError != nil {
                            HStack(spacing: 8) {
                                RoachDot(accent: RoachTheme.amber)
                                Text("The Apps catalog is offline. Showing the last shelf this phone loaded.")
                                    .font(RoachType.caption(.semibold))
                                    .foregroundStyle(RoachTheme.subduedText)
                            }
                            .accessibilityIdentifier("apps.catalogOffline")
                        }
                        searchField
                        appHandoffPanel
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
                    .padding(.bottom, RoachCompanionChrome.bottomContentClearance)
                }
                .roachTabBarScrollClearance()
                .refreshable {
                    try? await model.loadCatalog()
                    if model.connection.isConfigured {
                        await model.refreshAll()
                    }
                }
            }
            .navigationBarHidden(true)
            .animation(.snappy(duration: 0.26), value: model.selectedCategory)
            .animation(.spring(response: 0.34, dampingFraction: 0.82), value: model.queuedInstallCount)
            .sheet(
                item: Binding(
                    get: { model.selectedStoreItem },
                    set: { model.selectedStoreItem = $0 }
                )
            ) { item in
                AppDetailSheet(model: model, item: item)
            }
        }
    }

    private var appHandoffPanel: some View {
        RoachPanel {
            VStack(alignment: .leading, spacing: 12) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 10) {
                        handoffSteps
                        Spacer(minLength: 8)
                        handoffAction
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        handoffSteps
                        handoffAction
                    }
                }
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var handoffSteps: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                InstallFlowStep(
                    title: "Pick",
                    detail: "\(model.visibleCatalogItems.count) ready",
                    systemImage: "square.grid.2x2.fill",
                    accent: RoachTheme.tertiary,
                    isActive: true
                )
                InstallFlowStep(
                    title: "Send",
                    detail: model.connection.isConfigured ? "Bridge open" : "Pair Mac",
                    systemImage: model.connection.isConfigured ? "link" : "link.badge.plus",
                    accent: model.connection.isConfigured ? RoachTheme.secondary : RoachTheme.primary,
                    isActive: model.connection.isConfigured
                )
                InstallFlowStep(
                    title: "Stash",
                    detail: model.queuedInstallCount > 0 ? "\(model.queuedInstallCount) queued" : "Clear",
                    systemImage: model.queuedInstallCount > 0 ? "tray.full.fill" : "checkmark.seal.fill",
                    accent: model.queuedInstallCount > 0 ? RoachTheme.primary : RoachTheme.secondary,
                    isActive: model.queuedInstallCount == 0
                )
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(minimum: 0), spacing: 10),
                    GridItem(.flexible(minimum: 0), spacing: 10),
                ],
                alignment: .leading,
                spacing: 10
            ) {
                InstallFlowStep(
                    title: "Pick",
                    detail: "\(model.visibleCatalogItems.count) ready",
                    systemImage: "square.grid.2x2.fill",
                    accent: RoachTheme.tertiary,
                    isActive: true
                )
                InstallFlowStep(
                    title: "Send",
                    detail: model.connection.isConfigured ? "Bridge open" : "Pair Mac",
                    systemImage: model.connection.isConfigured ? "link" : "link.badge.plus",
                    accent: model.connection.isConfigured ? RoachTheme.secondary : RoachTheme.primary,
                    isActive: model.connection.isConfigured
                )
                InstallFlowStep(
                    title: "Stash",
                    detail: model.queuedInstallCount > 0 ? "\(model.queuedInstallCount) queued" : "Clear",
                    systemImage: model.queuedInstallCount > 0 ? "tray.full.fill" : "checkmark.seal.fill",
                    accent: model.queuedInstallCount > 0 ? RoachTheme.primary : RoachTheme.secondary,
                    isActive: model.queuedInstallCount == 0
                )
            }
        }
    }

    private var handoffAction: some View {
        Button {
            if model.connection.isConfigured {
                Task { await model.refreshAll() }
            } else {
                model.settingsPresented = true
            }
        } label: {
            Label(
                model.connection.isConfigured ? "Refresh bridge" : "Pair the Mac",
                systemImage: model.connection.isConfigured ? "arrow.clockwise" : "qrcode.viewfinder"
            )
            .font(RoachType.caption(.black))
            .lineLimit(1)
            .minimumScaleFactor(0.76)
            .frame(minWidth: 132)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        model.connection.isConfigured
                            ? RoachTheme.secondary.opacity(0.22) : RoachTheme.primary.opacity(0.24)
                    )
                    .overlay(
                        Capsule(style: .continuous)
                            .strokeBorder(
                                (model.connection.isConfigured ? RoachTheme.secondary : RoachTheme.primary).opacity(
                                    0.44), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(RoachPressableButtonStyle())
        .foregroundStyle(RoachTheme.text)
    }

    private var storeHeader: some View {
        RoachPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    RoachSectionHeader(
                        eyebrow: "Apps",
                        title: "Bring the useful parts home.",
                        detail:
                            "Maps, courses, models, and references move through the same install handoff the desktop already understands."
                    )

                    Spacer(minLength: 8)

                    Button {
                        model.selectedTab = .chat
                    } label: {
                        Image(systemName: "message.fill")
                            .font(RoachType.headline())
                    }
                    .buttonStyle(RoachButtonStyle(kind: .secondary, size: .compact))
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
                                .font(RoachType.caption(.bold))
                                .foregroundStyle(RoachTheme.secondary)
                                .tracking(1.2)

                            Text(item.title)
                                .font(RoachType.display(20))
                                .foregroundStyle(RoachTheme.text)
                                .lineLimit(2)

                            Text(item.summary)
                                .font(RoachType.subheadline())
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
                                RoachBadge(
                                    title: status,
                                    accent: model.connection.isConfigured ? RoachTheme.secondary : RoachTheme.primary)
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
                    detail:
                        "The companion app pulls the same install lanes that ship from apps.roachnet.org, just closer to hand.",
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
                    .buttonStyle(RoachPressableButtonStyle(scale: 0.94))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule(style: .continuous)
                            .fill(
                                model.selectedCategory == category
                                    ? RoachTheme.primary.opacity(0.26) : RoachTheme.surface.opacity(0.92)
                            )
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(
                                        model.selectedCategory == category
                                            ? RoachTheme.primary.opacity(0.55) : RoachTheme.border,
                                        lineWidth: 1
                                    )
                            )
                    )
                    .foregroundStyle(model.selectedCategory == category ? RoachTheme.text : RoachTheme.subduedText)
                }
            }
        }
    }

    private var sectionIntro: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoachSectionHeader(
                eyebrow: model.selectedCategory,
                title: model.selectedCategory == "Today"
                    ? "The fast start shelf." : "\(model.selectedCategory) on deck.",
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
                    .font(RoachType.headline())
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
                    .font(RoachType.headline())
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
                    .font(RoachType.headline())
                    .foregroundStyle(RoachTheme.text)

                HStack {
                    Text("These will flush after the companion bridge comes back.")
                        .font(RoachType.caption)
                        .foregroundStyle(RoachTheme.subduedText)

                    Spacer(minLength: 8)

                    Button {
                        model.clearPendingInstallQueue()
                    } label: {
                        Label("Clear", systemImage: "trash")
                            .labelStyle(.iconOnly)
                    }
                    .buttonStyle(RoachButtonStyle(kind: .secondary, size: .compact))
                    .tint(RoachTheme.primary)
                    .accessibilityLabel("Clear queued installs")
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(model.pendingInstallQueue.prefix(8)) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .top, spacing: 8) {
                                    Text(item.title)
                                        .font(RoachType.subheadline(.semibold))
                                        .foregroundStyle(RoachTheme.text)
                                        .lineLimit(2)

                                    Spacer(minLength: 4)

                                    Button {
                                        model.removeQueuedInstall(item)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(RoachType.caption(.bold))
                                    }
                                    .buttonStyle(.plain)
                                    .foregroundStyle(RoachTheme.subduedText)
                                    .accessibilityLabel("Remove \(item.title) from queue")
                                }

                                Text("Queued \(formattedRelativeDate(item.createdAt))")
                                    .font(RoachType.caption)
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
                    .font(RoachType.headline())
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
                            .font(RoachType.headline())
                            .foregroundStyle(RoachTheme.text)
                        Text("Pulling install metadata and shelf definitions.")
                            .font(RoachType.subheadline())
                            .foregroundStyle(RoachTheme.subduedText)
                    }
                    Spacer()
                }
            }
        } else {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(model.visibleCatalogItems) { item in
                    AppCard(model: model, item: item)
                        .transition(.scale(scale: 0.96).combined(with: .opacity))
                }
            }
        }
    }
}

private struct InstallFlowStep: View {
    let title: String
    let detail: String
    let systemImage: String
    let accent: Color
    let isActive: Bool

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: systemImage)
                .font(RoachType.caption(.bold))
                .foregroundStyle(Color.white)
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(accent.opacity(isActive ? 0.28 : 0.14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(accent.opacity(isActive ? 0.45 : 0.20), lineWidth: 1)
                        )
                )
                .symbolEffect(.pulse, value: detail)

            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(RoachType.caption2(.black))
                    .foregroundStyle(accent)
                    .tracking(0.8)
                Text(detail)
                    .font(RoachType.caption(.semibold))
                    .foregroundStyle(RoachTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
                    .contentTransition(.numericText())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(RoachTheme.elevatedSurface.opacity(isActive ? 0.92 : 0.68))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(accent.opacity(isActive ? 0.22 : 0.12), lineWidth: 1)
                )
        )
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
                    .font(RoachType.caption(.bold))
                    .foregroundStyle(RoachTheme.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Text(detail)
                .font(RoachType.caption2)
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
                            .font(RoachType.caption2)
                            .foregroundStyle(RoachTheme.subduedText)
                    }
                }

                Text(item.title)
                    .font(RoachType.headline())
                    .foregroundStyle(RoachTheme.text)
                    .lineLimit(2)

                Text(item.subtitle)
                    .font(RoachType.caption)
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
        .buttonStyle(RoachPressableButtonStyle(scale: 0.975))
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
                            .font(RoachType.caption)
                            .foregroundStyle(RoachTheme.subduedText)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(RoachType.headline())
                        .foregroundStyle(RoachTheme.text)
                        .lineLimit(2)

                    Text(item.subtitle)
                        .font(RoachType.caption)
                        .foregroundStyle(RoachTheme.subduedText)
                        .lineLimit(2)

                    Text(item.summary)
                        .font(RoachType.subheadline())
                        .foregroundStyle(RoachTheme.subduedText)
                        .lineLimit(2)
                }

                HStack(spacing: 8) {
                    Text(item.category)
                        .font(RoachType.caption2(.bold))
                        .foregroundStyle(RoachTheme.secondary)
                    if let status = item.status {
                        Text(status)
                            .font(RoachType.caption2(.bold))
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
                                            .font(RoachType.headline())
                                    }
                                    .buttonStyle(RoachButtonStyle(kind: .secondary, size: .compact))
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
                                        RoachMetricTile(
                                            label: "Shelf", value: status, accent: roachAccentColor(for: item.accent))
                                    }
                                }

                                if let machineFit = item.machineFit {
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: "desktopcomputer")
                                            .font(RoachType.headline())
                                            .foregroundStyle(roachAccentColor(for: item.accent))

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Mac fit")
                                                .font(RoachType.caption(.bold))
                                                .foregroundStyle(RoachTheme.secondary)
                                            Text(machineFit)
                                                .font(RoachType.caption)
                                                .foregroundStyle(RoachTheme.subduedText)
                                        }
                                    }
                                    .padding(12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(RoachTheme.elevatedSurface.opacity(0.88))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .strokeBorder(RoachTheme.border, lineWidth: 1)
                                    )
                                }

                                if !item.includes.isEmpty {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Inside")
                                            .font(RoachType.headline())
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
                                .font(RoachType.subheadline(.black))
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
                                        .strokeBorder(RoachTheme.neutralInk.opacity(0.16), lineWidth: 1)
                                )
                                .buttonStyle(.plain)
                                .frame(maxWidth: .infinity, alignment: .leading)

                                if let installURL = model.installDeepLink(for: item) {
                                    ShareLink(item: installURL) {
                                        Label("Share install link", systemImage: "square.and.arrow.up")
                                            .font(RoachType.subheadline(.bold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 12)
                                            .background(
                                                Capsule(style: .continuous)
                                                    .fill(RoachTheme.elevatedSurface.opacity(0.95))
                                            )
                                            .overlay(
                                                Capsule(style: .continuous)
                                                    .strokeBorder(RoachTheme.secondary.opacity(0.32), lineWidth: 1)
                                            )
                                    }
                                    .foregroundStyle(RoachTheme.text)
                                }
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
            Label(
                isInstalling ? "Installing…" : displayInstallLabel(for: item),
                systemImage: isInstalling ? "hourglass" : "square.and.arrow.down"
            )
            .font(RoachType.caption(.black))
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
                    .strokeBorder(RoachTheme.neutralInk.opacity(0.16), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.white)
        .disabled(isInstalling)
        .opacity(isInstalling ? 0.72 : 1)
        .buttonStyle(RoachPressableButtonStyle(scale: 0.97))
    }

    private var detailsButton: some View {
        Button("Details") {
            model.selectedStoreItem = item
        }
        .font(RoachType.caption(.bold))
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
        .buttonStyle(RoachPressableButtonStyle(scale: 0.97))
    }

    private var favoriteButton: some View {
        Button {
            model.toggleFavorite(item)
        } label: {
            Image(systemName: model.isFavorite(item) ? "heart.fill" : "heart")
                .font(RoachType.headline())
                .frame(maxWidth: .infinity)
        }
        .frame(height: 38)
        .background(
            Circle()
                .fill((model.isFavorite(item) ? RoachTheme.primary : RoachTheme.elevatedSurface).opacity(0.94))
        )
        .overlay(
            Circle()
                .strokeBorder(
                    (model.isFavorite(item) ? RoachTheme.primary : RoachTheme.secondary).opacity(0.34), lineWidth: 1)
        )
        .foregroundStyle(model.isFavorite(item) ? RoachTheme.text : RoachTheme.text)
        .buttonStyle(RoachPressableButtonStyle(scale: 0.92))
    }
}

private func displayInstallLabel(for item: StoreAppItem) -> String {
    guard let installLabel = item.installLabel, !installLabel.isEmpty else {
        return "Install"
    }
    return installLabel.contains("RoachNet") ? "Install" : installLabel
}

extension AppsView {
    fileprivate func favoriteButton(for item: StoreAppItem) -> some View {
        Button {
            model.toggleFavorite(item)
        } label: {
            Image(systemName: model.isFavorite(item) ? "heart.fill" : "heart")
                .font(RoachType.headline())
                .foregroundStyle(Color.white)
        }
        .buttonStyle(RoachButtonStyle(kind: .secondary, size: .compact))
        .tint(model.isFavorite(item) ? RoachTheme.primary : RoachTheme.secondary)
    }
}
