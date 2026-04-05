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

                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(model.visibleCatalogItems) { item in
                                AppCard(model: model, item: item)
                            }
                        }
                    }
                    .padding(16)
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
                    HStack {
                        StoreGlyph(
                            band: item.iconBand ?? "RoachNet",
                            monogram: item.iconMonogram ?? "APP",
                            accent: roachAccentColor(for: item.accent)
                        )
                        Spacer()
                        if let status = item.status {
                            RoachBadge(title: status, accent: roachAccentColor(for: item.accent))
                        }
                    }

                    Text(item.title)
                        .font(.title2.weight(.black))
                        .foregroundStyle(RoachTheme.text)

                    Text(item.summary)
                        .font(.subheadline)
                        .foregroundStyle(RoachTheme.subduedText)

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
                    detail: "The RoachNet Apps lane pulls the same installs the website serves.",
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
                        model.selectedCategory = category
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
            .frame(maxWidth: .infinity, minHeight: 256, alignment: .topLeading)
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

                                Text(item.title)
                                    .font(.title2.weight(.black))
                                    .foregroundStyle(RoachTheme.text)

                                Text(item.summary)
                                    .font(.body)
                                    .foregroundStyle(RoachTheme.subduedText)

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
