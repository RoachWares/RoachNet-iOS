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
    var favoriteItemIDs = Set<String>()
    var recentInstallIDs: [String] = []
    var pendingInstallQueue: [QueuedInstallItem] = CompanionPendingInstallStore.load()
    var lastRefreshAt: Date?
    var selectedCategory = "Today"
    var selectedStoreItem: StoreAppItem?
    var draft = ""
    var searchText = ""
    var isBootstrapping = false
    var isSending = false
    var installingItemIDs = Set<String>()
    var actingServiceNames = Set<String>()
    var isActingRoachTail = false
    var isActingRoachSync = false
    var bannerText: String?
    var errorText: String?
    var historyPresented = false
    var settingsPresented = false

    private static let roachTailPeerStorageKey = "RoachNetCompanionRoachTailPeerID"
    private let client = RoachNetAPIClient()
    private let forceDemoMode = CompanionLaunchOptions.forceDemoMode
    private let roachTailPeerID: String = {
        if let existing = UserDefaults.standard.string(forKey: roachTailPeerStorageKey), !existing.isEmpty {
            return existing
        }
        let generated = "ios-\(UUID().uuidString.lowercased())"
        UserDefaults.standard.set(generated, forKey: roachTailPeerStorageKey)
        return generated
    }()

    init() {
        if let snapshot = CompanionCacheStore.load(), !forceDemoMode {
            restore(snapshot)
        }

        if forceDemoMode {
            connection = CompanionConnectionSettings(
                baseURL: "http://RoachNet:38111",
                token: "preview-lane"
            )
        }

        if forceDemoMode || (!connection.isConfigured && runtime == nil && currentSession == nil) {
            applyDemoState()
        }

        if let screenshotTab = CompanionLaunchOptions.screenshotTab {
            selectedTab = screenshotTab
        }
    }

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

    var favoriteItems: [StoreAppItem] {
        catalogItems.filter { favoriteItemIDs.contains($0.id) }
    }

    var recentInstallItems: [StoreAppItem] {
        recentInstallIDs.compactMap { id in
            catalogItems.first(where: { $0.id == id })
        }
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
                .prefix(18)
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

    var roachTailIsLinked: Bool {
        runtime?.roachTail?.peers.contains(where: { $0.id == roachTailPeerID }) ?? false
    }

    var queuedInstallCount: Int {
        pendingInstallQueue.count
    }

    var usingRoachTailPeerToken: Bool {
        connection.usesRoachTailPeerToken
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

    func isFavorite(_ item: StoreAppItem) -> Bool {
        favoriteItemIDs.contains(item.id)
    }

    func bootstrapIfNeeded() async {
        guard !isBootstrapping else { return }

        if forceDemoMode {
            do {
                if catalogItems.isEmpty {
                    try await loadCatalog()
                }
            } catch {
                errorText = error.localizedDescription
            }
            applyDemoState()
            return
        }

        if connection.isConfigured {
            await refreshAll()
            return
        }

        if catalogItems.isEmpty {
            do {
                try await loadCatalog()
            } catch {
                errorText = error.localizedDescription
            }
        }

        applyDemoStateIfNeeded()
    }

    func refreshAll() async {
        isBootstrapping = true
        defer {
            isBootstrapping = false
            persistCache()
        }

        do {
            if forceDemoMode {
                try await loadCatalog()
                applyDemoState()
                lastRefreshAt = Date()
                errorText = nil
                return
            }

            if connection.isConfigured {
                let bootstrap = try await client.bootstrap(using: connection)
                appsCatalogURL = bootstrap.appsCatalogUrl
                pairedMachineName = bootstrap.machineName
                runtime = bootstrap.runtime
                vault = bootstrap.vault
                sessionList = bootstrap.sessions

                if
                    currentSession == nil || sessionList.contains(where: { $0.id == currentSession?.id }) == false,
                    let firstSession = bootstrap.sessions.first
                {
                    try? await loadSession(firstSession.id)
                }
            }

            try await loadCatalog()

            if connection.isConfigured {
                await flushPendingInstallQueue()
                if bannerText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true {
                    bannerText = "Connected to your desktop."
                }
            } else {
                applyDemoStateIfNeeded()
                bannerText = "Preview mode is ready. Link your Mac to go live."
            }

            lastRefreshAt = Date()
            errorText = nil
        } catch {
            errorText = error.localizedDescription
            if connection.isConfigured, let roachTailStatus = try? await client.roachTail(using: connection) {
                applyRoachTailStatus(roachTailStatus)
                lastRefreshAt = Date()
            }
            if catalogItems.isEmpty {
                try? await loadCatalog()
            }
            applyDemoStateIfNeeded()
        }
    }

    func loadCatalog() async throws {
        let response = try await client.fetchCatalog(from: appsCatalogURL)
        catalogItems = response.items

        if selectedCategory != "Today", !categories.contains(selectedCategory) {
            selectedCategory = "Today"
        }

        persistCache()
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

        persistCache()
    }

    func newChat() async {
        if !connection.isConfigured {
            let fallback = makeLocalSession(title: "Offline Chat")
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
            bannerText = "Offline chat is ready."
            errorText = nil
            persistCache()
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
            persistCache()
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
            persistCache()
        }
    }

    func sendDraft() async {
        let trimmedDraft = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDraft.isEmpty else { return }

        let draftToSend = trimmedDraft
        let existingMessages = currentSession?.messages ?? []
        let activeSession = currentSession ?? makeLocalSession(title: "New Chat")
        let localMessage = CompanionChatMessage(
            rawID: FlexibleIdentifier("draft-\(UUID().uuidString)"),
            role: "user",
            content: draftToSend,
            createdAt: Date()
        )

        currentSession = CompanionChatSessionDetail(
            rawID: activeSession.rawID,
            title: activeSession.title,
            model: activeSession.model,
            timestamp: Date(),
            messages: existingMessages + [localMessage]
        )
        draft = ""
        isSending = true
        defer {
            isSending = false
            persistCache()
        }

        if connection.isConfigured {
            do {
                let response = try await client.sendMessage(
                    sessionID: activeSession.id.hasPrefix("local-") ? nil : activeSession.id,
                    content: draftToSend,
                    history: existingMessages,
                    using: connection
                )

                merge(session: response.session)
                currentSession = CompanionChatSessionDetail(
                    rawID: FlexibleIdentifier(response.session.id),
                    title: response.session.title,
                    model: response.session.model,
                    timestamp: response.session.timestamp,
                    messages: existingMessages + [response.userMessage, response.assistantMessage]
                )
                bannerText = "RoachClaw replied."
                errorText = nil
                return
            } catch {
                bannerText = "RoachClaw is offline. Falling back to the phone lane."
            }
        }

        let assistantMessage = CompanionChatMessage(
            rawID: FlexibleIdentifier("offline-\(UUID().uuidString.lowercased())"),
            role: "assistant",
            content: localOfflineAssistantReply(for: draftToSend),
            createdAt: Date()
        )

        currentSession = CompanionChatSessionDetail(
            rawID: activeSession.rawID,
            title: activeSession.title,
            model: activeSession.model ?? activeModelName ?? "RoachBrain offline",
            timestamp: Date(),
            messages: existingMessages + [localMessage, assistantMessage]
        )

        merge(
            session: CompanionChatSessionSummary(
                rawID: activeSession.rawID,
                title: activeSession.title,
                model: activeSession.model ?? activeModelName ?? "RoachBrain offline",
                timestamp: Date()
            )
        )
        errorText = nil
    }

    func install(_ item: StoreAppItem) async {
        guard let intent = item.installIntent else {
            errorText = "This app entry does not expose an install intent yet."
            return
        }

        if !connection.isConfigured {
            queueInstall(item.title, intent: intent)
            bannerText = "\(item.title) is queued until the desktop comes back."
            errorText = nil
            return
        }

        installingItemIDs.insert(item.id)
        defer { installingItemIDs.remove(item.id) }

        do {
            _ = try await client.install(intent: intent, using: connection)
            recordRecentInstall(item.id)
            bannerText = "\(item.title) was sent to RoachNet."
            errorText = nil
            persistCache()
        } catch {
            queueInstall(item.title, intent: intent)
            bannerText = "\(item.title) is queued until the desktop comes back."
            errorText = nil
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
                lastRefreshAt = Date()
                persistCache()
            } catch {
                errorText = error.localizedDescription
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    func pairWithRoachTail() async {
        guard connection.resolvedBaseURL != nil else {
            errorText = "Add the companion URL before pairing with RoachTail."
            return
        }

        let joinCode = connection.pairCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !joinCode.isEmpty else {
            errorText = "Paste the RoachTail join code from your Mac first."
            return
        }

        isActingRoachTail = true
        defer { isActingRoachTail = false }

        do {
            let response = try await client.pairRoachTail(
                joinCode: joinCode,
                peerID: roachTailPeerID,
                peerName: companionPeerName,
                platform: "ios",
                appVersion: currentAppVersion,
                tags: companionPeerTags,
                using: connection
            )

            connection.token = response.token
            if let bridgeUrl = response.bridgeUrl, !bridgeUrl.isEmpty {
                connection.baseURL = bridgeUrl
            }
            connection.save()
            runtime = response.state.map { existing in
                CompanionRuntimeSummary(
                    systemInfo: runtime?.systemInfo,
                    providers: runtime?.providers ?? CompanionProviderEnvelope(providers: [:]),
                    roachClaw: runtime?.roachClaw ?? CompanionDemoState.runtime.roachClaw,
                    roachTail: existing,
                    roachSync: runtime?.roachSync ?? CompanionDemoState.runtime.roachSync,
                    services: runtime?.services ?? [],
                    downloads: runtime?.downloads ?? [],
                    installedModels: runtime?.installedModels ?? [],
                    issues: runtime?.issues ?? []
                )
            } ?? runtime
            bannerText = response.message ?? "RoachTail pairing is ready."
            errorText = nil
            await refreshAll()
        } catch {
            errorText = error.localizedDescription
        }
    }

    func applyRoachTailPairingPayload(_ rawPayload: String) {
        let trimmedPayload = rawPayload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPayload.isEmpty, let payloadData = trimmedPayload.data(using: .utf8) else {
            errorText = "That QR code did not contain RoachTail pairing data."
            return
        }

        do {
            let payload = try JSONDecoder().decode(CompanionRoachTailPairingPayload.self, from: payloadData)

            if let bridgeURL = payload.bridgeUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !bridgeURL.isEmpty {
                connection.baseURL = bridgeURL
            } else if let runtimeTunnelURL = payload.runtimeTunnelUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !runtimeTunnelURL.isEmpty {
                connection.baseURL = runtimeTunnelURL
            } else if let runtimeOrigin = payload.runtimeOrigin?.trimmingCharacters(in: .whitespacesAndNewlines), !runtimeOrigin.isEmpty {
                connection.baseURL = runtimeOrigin
            }

            connection.pairCode = payload.joinCode
            connection.token = ""
            connection.save()
            bannerText = "RoachTail pairing data loaded."
            errorText = nil
        } catch {
            errorText = "That QR code was not a valid RoachTail pairing payload."
        }
    }

    func affectRoachTail(_ action: String) async {
        guard connection.isConfigured else {
            settingsPresented = true
            errorText = "Link your Mac companion lane before changing RoachTail."
            return
        }

        isActingRoachTail = true
        defer { isActingRoachTail = false }

        do {
            let result = try await client.affectRoachTail(action: action, using: connection)
            bannerText = result.message ?? "RoachTail updated."
            errorText = nil
            try await refreshRuntimeAfterRoachTailAction()
        } catch {
            errorText = error.localizedDescription
        }
    }

    func affectRoachSync(_ action: String, folderPath: String? = nil) async {
        guard connection.isConfigured else {
            settingsPresented = true
            errorText = "Link your Mac companion lane before changing RoachSync."
            return
        }

        isActingRoachSync = true
        defer { isActingRoachSync = false }

        do {
            let result = try await client.affectRoachSync(
                action: action,
                folderPath: folderPath,
                using: connection
            )
            bannerText = result.message ?? "RoachSync updated."
            errorText = nil
            runtime = try await client.runtime(using: connection)
            lastRefreshAt = Date()
            persistCache()
        } catch {
            errorText = error.localizedDescription
        }
    }

    func linkThisDeviceToRoachTail() async {
        guard connection.isConfigured else {
            settingsPresented = true
            errorText = "Link your Mac companion lane before adding this device to RoachTail."
            return
        }

        isActingRoachTail = true
        defer { isActingRoachTail = false }

        do {
            let result = try await client.affectRoachTail(
                action: "register-peer",
                peerID: roachTailPeerID,
                peerName: companionPeerName,
                platform: "ios",
                tags: companionPeerTags,
                using: connection
            )
            bannerText = result.message ?? "This device joined RoachTail."
            errorText = nil
            try await refreshRuntimeAfterRoachTailAction()
        } catch {
            errorText = error.localizedDescription
        }
    }

    func unlinkThisDeviceFromRoachTail() async {
        guard connection.isConfigured else {
            settingsPresented = true
            errorText = "Link your Mac companion lane before changing RoachTail peers."
            return
        }

        isActingRoachTail = true
        defer { isActingRoachTail = false }

        do {
            let result = try await client.affectRoachTail(
                action: "remove-peer",
                peerID: roachTailPeerID,
                using: connection
            )
            if connection.usesRoachTailPeerToken {
                connection.token = ""
                connection.save()
                bannerText = result.message ?? "This device was removed from RoachTail."
                errorText = nil
                persistCache()
                return
            }

            bannerText = result.message ?? "This device was removed from RoachTail."
            errorText = nil
            try await refreshRuntimeAfterRoachTailAction()
        } catch {
            errorText = error.localizedDescription
        }
    }

    func toggleFavorite(_ item: StoreAppItem) {
        if favoriteItemIDs.contains(item.id) {
            favoriteItemIDs.remove(item.id)
        } else {
            favoriteItemIDs.insert(item.id)
        }
        persistCache()
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

    private func makeLocalSession(title: String) -> CompanionChatSessionDetail {
        CompanionChatSessionDetail(
            rawID: FlexibleIdentifier("local-\(UUID().uuidString)"),
            title: title,
            model: runtime?.roachClaw.resolvedDefaultModel ?? runtime?.roachClaw.defaultModel,
            timestamp: Date(),
            messages: []
        )
    }

    private func recordRecentInstall(_ itemID: String) {
        recentInstallIDs.removeAll { $0 == itemID }
        recentInstallIDs.insert(itemID, at: 0)
        recentInstallIDs = Array(recentInstallIDs.prefix(8))
    }

    private var companionPeerName: String {
        "RoachNet Companion"
    }

    private var companionPeerTags: [String] {
        ["ios", "companion", "roachtail"]
    }

    private var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.1.2"
    }

    private func queueInstall(_ title: String, intent: StoreInstallIntent) {
        let queued = QueuedInstallItem(
            id: "queued-\(UUID().uuidString.lowercased())",
            title: title,
            createdAt: Date(),
            intent: intent
        )
        pendingInstallQueue.insert(queued, at: 0)
        pendingInstallQueue = Array(pendingInstallQueue.prefix(24))
        CompanionPendingInstallStore.save(pendingInstallQueue)
        persistCache()
    }

    private func flushQueuedInstall(_ item: QueuedInstallItem) async throws {
        _ = try await client.install(intent: item.intent, using: connection)
        if let matchedItem = catalogItems.first(where: { $0.title == item.title }) {
            recordRecentInstall(matchedItem.id)
        }
    }

    private func flushPendingInstallQueue() async {
        guard connection.isConfigured, !pendingInstallQueue.isEmpty else { return }

        var remaining = pendingInstallQueue
        var flushedTitles: [String] = []

        for item in pendingInstallQueue {
            do {
                try await flushQueuedInstall(item)
                remaining.removeAll { $0.id == item.id }
                flushedTitles.append(item.title)
            } catch {
                break
            }
        }

        pendingInstallQueue = remaining
        CompanionPendingInstallStore.save(remaining)

        if !flushedTitles.isEmpty {
            bannerText = "\(flushedTitles.count) queued install\(flushedTitles.count == 1 ? "" : "s") reached RoachNet."
        }
    }

    private func localOfflineAssistantReply(for prompt: String) -> String {
        OfflineRoachBrain.reply(
            for: prompt,
            context: OfflineRoachBrainContext(
                runtime: runtime,
                vault: vault,
                catalogItems: catalogItems,
                pendingInstalls: pendingInstallQueue,
                recentInstallItems: recentInstallItems,
                featuredItem: featuredItem,
                activeModelName: activeModelName
            )
        )
    }

    private func refreshRuntimeAfterRoachTailAction() async throws {
        do {
            runtime = try await client.runtime(using: connection)
        } catch {
            let roachTailStatus = try await client.roachTail(using: connection)
            applyRoachTailStatus(roachTailStatus)
        }

        lastRefreshAt = Date()
        persistCache()
    }

    private func applyRoachTailStatus(_ status: CompanionRoachTailStatus) {
        let existing = runtime ?? CompanionDemoState.runtime
        runtime = CompanionRuntimeSummary(
            systemInfo: existing.systemInfo,
            providers: existing.providers,
            roachClaw: existing.roachClaw,
            roachTail: status,
            roachSync: existing.roachSync,
            services: existing.services,
            downloads: existing.downloads,
            installedModels: existing.installedModels,
            issues: existing.issues
        )
        persistCache()
    }

    private func persistCache() {
        let snapshot = CompanionCacheSnapshot(
            appsCatalogURL: appsCatalogURL,
            pairedMachineName: pairedMachineName,
            sessionList: sessionList,
            currentSession: currentSession,
            runtime: runtime,
            vault: vault,
            catalogItems: catalogItems,
            favoriteItemIDs: Array(favoriteItemIDs).sorted(),
            recentInstallIDs: recentInstallIDs,
            lastRefreshAt: lastRefreshAt
        )
        CompanionCacheStore.save(snapshot)
    }

    private func restore(_ snapshot: CompanionCacheSnapshot) {
        appsCatalogURL = snapshot.appsCatalogURL
        pairedMachineName = snapshot.pairedMachineName
        sessionList = snapshot.sessionList
        currentSession = snapshot.currentSession
        runtime = snapshot.runtime
        vault = snapshot.vault
        catalogItems = snapshot.catalogItems
        favoriteItemIDs = Set(snapshot.favoriteItemIDs)
        recentInstallIDs = snapshot.recentInstallIDs
        lastRefreshAt = snapshot.lastRefreshAt
    }

    private func applyDemoStateIfNeeded() {
        guard runtime == nil || vault == nil || currentSession == nil else { return }
        applyDemoState()
    }

    private func applyDemoState() {
        pairedMachineName = nil
        if catalogItems.isEmpty {
            catalogItems = CompanionDemoState.catalogItems
        }
        if favoriteItemIDs.isEmpty, let firstDemoItem = catalogItems.first {
            favoriteItemIDs = [firstDemoItem.id]
        }
        if recentInstallIDs.isEmpty, catalogItems.count > 1 {
            recentInstallIDs = [catalogItems[1].id]
        }
        sessionList = CompanionDemoState.sessionList
        currentSession = CompanionDemoState.currentSession
        runtime = CompanionDemoState.runtime
        vault = CompanionDemoState.vault
        bannerText = "Preview mode is ready. Link your Mac to go live."
        persistCache()
    }
}
