import SwiftUI

struct AppsView: View {
    @Bindable var model: CompanionAppModel
    private let columns = [GridItem(.adaptive(minimum: 170), spacing: 14)]

    var body: some View {
        NavigationStack {
            ZStack {
                RoachBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        featuredCard
                        searchField
                        categoryStrip
                        sectionIntro
                        spotlightRow
                        catalogGrid
                    }
                    .padding(16)
                }
                .refreshable {
                    try? await model.loadCatalog()
                    if model.connection.isConfigured {
                        await model.refreshAll()
                    }
                }
            }
            .navigationTitle("Apps")
            .sheet(item: Binding(
                get: { model.selectedStoreItem },
                set: { model.selectedStoreItem = $0 }
            )) { item in
                AppDetailSheet(model: model, item: item)
            }
        }
    }

    private var featuredCard: some View {
        let item = model.featuredItem
        return RoachPanel {
            if let item {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .top) {
                        StoreGlyph(
                            band: item.iconBand ?? "RoachNet",
                            monogram: item.iconMonogram ?? "APP",
                            accent: roachAccentColor(for: item.accent)
                        )

                        Spacer()

                        VStack(alignment: .trailing, spacing: 8) {
                            RoachBadge(title: model.connection.isConfigured ? "Install-ready" : "Link Mac first", accent: model.connection.isConfigured ? RoachTheme.secondary : RoachTheme.primary)
                            if let status = item.status {
                                RoachBadge(title: status, accent: roachAccentColor(for: item.accent))
                            }
                        }
                    }

                    RoachSectionHeader(
                        eyebrow: "Today",
                        title: item.title,
                        detail: item.summary
                    )

                    HStack(spacing: 10) {
                        Button(item.installLabel ?? "Install to RoachNet") {
                            Task { await model.install(item) }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(RoachTheme.primary)

                        Button("Preview") {
                            model.selectedStoreItem = item
                        }
                        .buttonStyle(.bordered)
                        .tint(RoachTheme.secondary)
                    }
                }
            } else {
                EmptyStateView(
                    title: "Apps catalog",
                    detail: "The companion app pulls the same install lanes that ship from apps.roachnet.org.",
                    actionTitle: nil,
                    action: nil
                )
            }
        }
    }

    private var searchField: some View {
        TextField("Search apps, maps, courses, or models", text: $model.searchText)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
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
        RoachPanel {
            VStack(alignment: .leading, spacing: 10) {
                RoachSectionHeader(
                    eyebrow: model.selectedCategory,
                    title: model.selectedCategory == "Today" ? "The fast start shelf." : "\(model.selectedCategory) installs.",
                    detail: model.categoryDescription(for: model.selectedCategory)
                )

                HStack(spacing: 10) {
                    RoachMetricTile(
                        label: "Apps",
                        value: "\(model.appCount(for: model.selectedCategory))",
                        accent: RoachTheme.secondary
                    )

                    RoachMetricTile(
                        label: "Link",
                        value: model.connection.isConfigured ? "Ready" : "Needs pairing",
                        accent: model.connection.isConfigured ? RoachTheme.tertiary : RoachTheme.primary
                    )
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
            .frame(width: 220, alignment: .leading)
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
                        .lineLimit(3)
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

                HStack(spacing: 10) {
                    Button(item.installLabel ?? "Install") {
                        Task { await model.install(item) }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(roachAccentColor(for: item.accent))
                    .disabled(model.installingItemIDs.contains(item.id))

                    Button("More") {
                        model.selectedStoreItem = item
                    }
                    .buttonStyle(.bordered)
                    .tint(RoachTheme.secondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 270, alignment: .topLeading)
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

                                Button(item.installLabel ?? "Install to RoachNet") {
                                    Task { await model.install(item) }
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(RoachTheme.primary)
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
