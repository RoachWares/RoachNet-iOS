import Foundation
import Observation

enum CompanionTab: Hashable {
    case chat
    case vault
    case apps
    case runtime
}

@MainActor
@Observable
final class CompanionAppModel {
    var connection = CompanionConnectionSettings.load() {
        didSet { connection.save() }
    }

    var selectedTab: CompanionTab = .chat
    var appsCatalogURL = "https://apps.roachnet.org/app-store-catalog.json"
    var pairedMachineName: String?
    var sessionList: [CompanionChatSessionSummary] = []
    var currentSession: CompanionChatSessionDetail?
    var runtime: CompanionRuntimeSummary?
    var vault: CompanionVaultSummary?
    var catalogItems: [StoreAppItem] = []
    var selectedCategory = "Today"
    var selectedStoreItem: StoreAppItem?
    var draft = ""
    var searchText = ""
    var isBootstrapping = false
    var isSending = false
    var installingItemIDs = Set<String>()
    var actingServiceNames = Set<String>()
    var bannerText: String?
    var errorText: String?
    var historyPresented = false
    var settingsPresented = false

    private let client = RoachNetAPIClient()

    var featuredItem: StoreAppItem? {
        if let firstFeatured = catalogItems.first(where: { $0.featured == true }) {
            return firstFeatured
        }
        return catalogItems.first
    }

    var categories: [String] {
        let catalogCategories = Set(catalogItems.map(\.category))
        let preferredOrder = [
            "Map Regions",
            "Medicine",
            "Survival",
            "Education",
            "DIY",
            "Agriculture",
            "Dev",
            "ML",
            "Audio",
            "Infra",
            "Wikipedia",
            "Models",
            "Travel",
            "Science",
            "Maker",
            "Design",
            "Deep Library",
        ]

        let ordered = preferredOrder.filter { catalogCategories.contains($0) }
        let remainder = catalogCategories.subtracting(preferredOrder).sorted()
        return ["Today"] + ordered + remainder
    }

    var activeModelName: String? {
        currentSession?.model ?? runtime?.roachClaw.resolvedDefaultModel ?? runtime?.roachClaw.defaultModel
    }

    var spotlightItems: [StoreAppItem] {
        if selectedCategory == "Today" {
            let featured = catalogItems.filter { $0.featured == true }
            if !featured.isEmpty {
                return Array(featured.prefix(6))
            }
        }

        let source = selectedCategory == "Today"
            ? catalogItems
            : catalogItems.filter { $0.category == selectedCategory }
        return Array(source.prefix(6))
    }

    var visibleCatalogItems: [StoreAppItem] {
        let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let baseItems: [StoreAppItem]

        if selectedCategory == "Today" {
            baseItems = catalogItems
                .sorted { ($0.featured ?? false) && !($1.featured ?? false) }
                .prefix(16)
                .map { $0 }
        } else {
            baseItems = catalogItems.filter { $0.category == selectedCategory }
        }

        guard !trimmedQuery.isEmpty else { return baseItems }

        return baseItems.filter { item in
            item.title.lowercased().contains(trimmedQuery) ||
            item.subtitle.lowercased().contains(trimmedQuery) ||
            item.summary.lowercased().contains(trimmedQuery) ||
            item.section.lowercased().contains(trimmedQuery)
        }
    }

    var runtimeIssues: [CompanionIssue] {
        (runtime?.issues ?? []) + (vault?.issues ?? [])
    }

    func categoryDescription(for category: String) -> String {
        switch category {
        case "Today":
            return "The fastest installs and the best lanes to start with."
        case "Map Regions":
            return "Regional atlas packs built for real routes, city grids, and empty stretches in between."
        case "Medicine":
            return "Field guides, drug references, treatment steps, and deeper medical shelves."
        case "Survival":
            return "Preparedness guides, winter planning, bug-out thinking, and field manuals."
        case "Education":
            return "Course packs, study shelves, and open learning lanes that feel like a small campus."
        case "DIY":
            return "Repair, woodworking, practical builds, and hands-on home/shop references."
        case "Agriculture":
            return "Food systems, gardening, homestead notes, and agricultural references."
        case "Dev":
            return "Programming docs, dev references, and coding shelves built to sit next to the editor."
        case "ML":
            return "Machine learning and AI references, model guides, and data science study packs."
        case "Audio":
            return "Music production, sound design, mixing, synthesis, and engineering references."
        case "Infra":
            return "Ops, networking, containers, servers, privacy, and infrastructure docs."
        case "Wikipedia":
            return "Right-sized encyclopedia lanes for broad reference without opening a browser maze."
        case "Models":
            return "Model packs, local AI defaults, and RoachClaw expansion lanes."
        case "Travel":
            return "Guides, route planning references, and location shelves that travel well."
        case "Science":
            return "Physics, chemistry, earth science, astronomy, and experiment-heavy references."
        case "Maker":
            return "Electronics, fabrication, hobby build docs, and tool-first learning lanes."
        case "Design":
            return "Typography, UI, visual design, and creative-tool learning/reference content."
        case "Deep Library":
            return "Larger archives and heavier shelves for broad browsing when storage is not tight."
        default:
            return "Install-ready content that lands straight in the paired RoachNet desktop."
        }
    }

    func appCount(for category: String) -> Int {
        if category == "Today" {
            return spotlightItems.count
        }
        return catalogItems.filter { $0.category == category }.count
    }

    func bootstrapIfNeeded() async {
        guard !isBootstrapping else { return }
        if runtime != nil || vault != nil || !catalogItems.isEmpty {
            return
        }
        await refreshAll()
    }

    func refreshAll() async {
        isBootstrapping = true
        defer { isBootstrapping = false }

        do {
            try await loadCatalog()

            guard connection.isConfigured else {
                bannerText = "Add your Mac companion URL and token to link the phone app."
                return
            }

            let bootstrap = try await client.bootstrap(using: connection)
            appsCatalogURL = bootstrap.appsCatalogUrl
            pairedMachineName = bootstrap.machineName
            runtime = bootstrap.runtime
            vault = bootstrap.vault
            sessionList = bootstrap.sessions

            if currentSession == nil, let firstSession = bootstrap.sessions.first {
                try? await loadSession(firstSession.id)
            }

            bannerText = "Connected to your desktop."
            errorText = nil
        } catch {
            errorText = error.localizedDescription
            if catalogItems.isEmpty {
                try? await loadCatalog()
            }
        }
    }

    func loadCatalog() async throws {
        let response = try await client.fetchCatalog(from: appsCatalogURL)
        catalogItems = response.items
        if selectedCategory != "Today", !categories.contains(selectedCategory) {
            selectedCategory = "Today"
        }
    }

    func loadSession(_ id: String) async throws {
        let session = try await client.session(id: id, using: connection)
        currentSession = session

        if let existingIndex = sessionList.firstIndex(where: { $0.id == session.id }) {
            sessionList[existingIndex] = CompanionChatSessionSummary(
                rawID: FlexibleIdentifier(session.id),
                title: session.title,
                model: session.model,
                timestamp: session.timestamp
            )
        }
    }

    func newChat() async {
        guard connection.isConfigured else {
            settingsPresented = true
            bannerText = "Link your Mac before starting chat."
            return
        }

        do {
            let session = try await client.createSession(using: connection)
            sessionList.insert(session, at: 0)
            currentSession = CompanionChatSessionDetail(
                rawID: FlexibleIdentifier(session.id),
                title: session.title,
                model: session.model,
                timestamp: session.timestamp,
                messages: []
            )
            bannerText = "New chat ready."
            errorText = nil
        } catch {
            let fallback = makeLocalSession(title: "New Chat")
            currentSession = fallback
            sessionList.insert(
                CompanionChatSessionSummary(
                    rawID: fallback.rawID,
                    title: fallback.title,
                    model: fallback.model,
                    timestamp: fallback.timestamp
                ),
                at: 0
            )
            bannerText = "New local chat ready."
            errorText = nil
        }
    }

    func sendDraft() async {
        let trimmedDraft = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDraft.isEmpty else { return }
        guard connection.isConfigured else {
            settingsPresented = true
            errorText = "Link your Mac companion lane before sending chat."
            return
        }

        isSending = true
        defer { isSending = false }

        do {
            let response = try await client.sendMessage(
                sessionID: currentSession?.id,
                content: trimmedDraft,
                history: currentSession?.messages ?? [],
                using: connection
            )

            draft = ""
            merge(session: response.session)
            append(message: response.userMessage, to: response.session)
            append(message: response.assistantMessage, to: response.session)
            bannerText = "RoachClaw replied."
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }

    func install(_ item: StoreAppItem) async {
        guard connection.isConfigured else {
            settingsPresented = true
            errorText = "Link your Mac companion lane before sending installs."
            return
        }

        guard let intent = item.installIntent else {
            errorText = "This app entry does not expose an install intent yet."
            return
        }

        installingItemIDs.insert(item.id)
        defer { installingItemIDs.remove(item.id) }

        do {
            _ = try await client.install(intent: intent, using: connection)
            bannerText = "\(item.title) was sent to RoachNet."
            errorText = nil
        } catch {
            errorText = error.localizedDescription
        }
    }

    func affectService(_ serviceName: String, action: String) async {
        let trimmedName = serviceName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        actingServiceNames.insert(trimmedName)
        defer { actingServiceNames.remove(trimmedName) }

        do {
            let result = try await client.affectService(
                serviceName: trimmedName,
                action: action,
                using: connection
            )
            bannerText = result.message ?? "\(trimmedName) queued for \(action)."
            errorText = nil

            do {
                runtime = try await client.runtime(using: connection)
            } catch {
                errorText = error.localizedDescription
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    func iconURL(for item: StoreAppItem) -> URL? {
        guard let iconAsset = item.iconAsset else { return nil }
        guard let catalogBase = URL(string: appsCatalogURL) else { return nil }
        return URL(string: iconAsset, relativeTo: catalogBase)
    }

    func clearBanner() {
        bannerText = nil
        errorText = nil
    }

    private func merge(session: CompanionChatSessionSummary) {
        if let index = sessionList.firstIndex(where: { $0.id == session.id }) {
            sessionList[index] = session
        } else {
            sessionList.insert(session, at: 0)
        }

        if currentSession?.id != session.id {
            currentSession = CompanionChatSessionDetail(
                rawID: FlexibleIdentifier(session.id),
                title: session.title,
                model: session.model,
                timestamp: session.timestamp,
                messages: []
            )
        }
    }

    private func append(message: CompanionChatMessage, to session: CompanionChatSessionSummary) {
        guard currentSession?.id == session.id else { return }

        var messages = currentSession?.messages ?? []
        messages.append(message)
        currentSession = CompanionChatSessionDetail(
            rawID: FlexibleIdentifier(session.id),
            title: session.title,
            model: session.model,
            timestamp: session.timestamp,
            messages: messages
        )
    }

    private func makeLocalSession(title: String) -> CompanionChatSessionDetail {
        CompanionChatSessionDetail(
            rawID: FlexibleIdentifier("local-\(UUID().uuidString)"),
            title: title,
            model: runtime?.roachClaw.resolvedDefaultModel ?? runtime?.roachClaw.defaultModel,
            timestamp: Date(),
            messages: []
        )
    }
}
