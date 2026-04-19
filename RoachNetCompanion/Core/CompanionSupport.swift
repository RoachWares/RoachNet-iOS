import Foundation

struct CompanionCacheSnapshot: Codable, Sendable {
    let appsCatalogURL: String
    let pairedMachineName: String?
    let sessionList: [CompanionChatSessionSummary]
    let currentSession: CompanionChatSessionDetail?
    let runtime: CompanionRuntimeSummary?
    let vault: CompanionVaultSummary?
    let catalogItems: [StoreAppItem]
    let favoriteItemIDs: [String]
    let recentInstallIDs: [String]
    let lastRefreshAt: Date?
}

enum CompanionCacheStore {
    private static let storageKey = "RoachNetCompanionCacheSnapshot"
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func load() -> CompanionCacheSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return nil
        }

        return try? decoder.decode(CompanionCacheSnapshot.self, from: data)
    }

    static func save(_ snapshot: CompanionCacheSnapshot) {
        guard let data = try? encoder.encode(snapshot) else {
            return
        }

        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

struct QueuedInstallItem: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let createdAt: Date
    let intent: StoreInstallIntent
}

enum CompanionPendingInstallStore {
    private static let storageKey = "RoachNetCompanionPendingInstalls"
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func load() -> [QueuedInstallItem] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return []
        }

        return (try? decoder.decode([QueuedInstallItem].self, from: data)) ?? []
    }

    static func save(_ items: [QueuedInstallItem]) {
        guard let data = try? encoder.encode(items) else {
            return
        }

        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

struct OfflineRoachBrainContext: Sendable {
    let runtime: CompanionRuntimeSummary?
    let vault: CompanionVaultSummary?
    let catalogItems: [StoreAppItem]
    let pendingInstalls: [QueuedInstallItem]
    let recentInstallItems: [StoreAppItem]
    let featuredItem: StoreAppItem?
    let activeModelName: String?
}

enum OfflineRoachBrain {
    static func reply(for prompt: String, context: OfflineRoachBrainContext) -> String {
        let trimmedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmedPrompt.lowercased()

        if normalized.contains("model") || normalized.contains("roachclaw") {
            return modelReply(context: context)
        }

        if normalized.contains("runtime") || normalized.contains("service") || normalized.contains("health") {
            return runtimeReply(context: context)
        }

        if normalized.contains("vault") || normalized.contains("roachbrain") || normalized.contains("note") {
            return vaultReply(context: context)
        }

        if normalized.contains("install") || normalized.contains("download") || normalized.contains("queue") {
            return installReply(context: context)
        }

        if normalized.contains("what should i") || normalized.contains("recommend") || normalized.contains("suggest") {
            return recommendationReply(query: normalized, context: context)
        }

        if let categoryReply = categoryReply(query: normalized, context: context) {
            return categoryReply
        }

        return overviewReply(context: context)
    }

    private static func modelReply(context: OfflineRoachBrainContext) -> String {
        let modelName = context.activeModelName ?? context.runtime?.roachClaw.defaultModel ?? "the last synced RoachClaw lane"
        let readiness = context.runtime?.roachClaw.ready == true ? "last sync showed it healthy" : "the desktop lane is out of reach right now"
        return "Offline RoachBrain: the last synced model was \(modelName), and \(readiness)."
    }

    private static func runtimeReply(context: OfflineRoachBrainContext) -> String {
        let services = context.runtime?.services.prefix(3).map { $0.friendlyName ?? $0.serviceName }.joined(separator: ", ")
        let servicesLine = services?.isEmpty == false ? services! : "the contained runtime"
        let roachTailState = context.runtime?.roachTail?.status ?? "local-only"
        return "Offline RoachBrain: last sync showed \(servicesLine) and RoachTail in \(roachTailState) mode."
    }

    private static func vaultReply(context: OfflineRoachBrainContext) -> String {
        let topNotes = context.vault?.roachBrain.prefix(2).map { "\($0.title): \($0.summary)" } ?? []
        if !topNotes.isEmpty {
            return """
            Offline RoachBrain notes:
            \(topNotes.joined(separator: "\n"))
            """
        }

        let archiveCount = context.vault?.siteArchives.count ?? 0
        let fileCount = context.vault?.knowledgeFiles.count ?? 0
        return "Offline RoachBrain: I still have cached vault state here with \(fileCount) indexed files and \(archiveCount) archived sites."
    }

    private static func installReply(context: OfflineRoachBrainContext) -> String {
        let queued = context.pendingInstalls.prefix(3).map(\.title)
        if !queued.isEmpty {
            return "Offline RoachBrain: queued for the next reconnect: \(queued.joined(separator: ", "))."
        }

        let recent = context.recentInstallItems.prefix(3).map(\.title)
        if !recent.isEmpty {
            return "Offline RoachBrain: the last installs I remember are \(recent.joined(separator: ", "))."
        }

        return "Offline RoachBrain: the Apps lane is still usable here. Pick something and I will queue it until the desktop comes back."
    }

    private static func recommendationReply(query: String, context: OfflineRoachBrainContext) -> String {
        let matches = topCatalogMatches(for: query, in: context.catalogItems, limit: 3)
        if matches.isEmpty {
            return overviewReply(context: context)
        }

        let lines = matches.map { "• \($0.title) — \($0.subtitle)" }
        return """
        Offline RoachBrain picks:
        \(lines.joined(separator: "\n"))
        """
    }

    private static func categoryReply(query: String, context: OfflineRoachBrainContext) -> String? {
        let categories: [(tokens: [String], name: String)] = [
            (["map", "atlas", "route", "region"], "Map Regions"),
            (["med", "medicine", "health", "drug", "medical"], "Medicine"),
            (["survival", "prep", "bug out", "winter"], "Survival"),
            (["course", "study", "school", "education"], "Education"),
            (["dev", "code", "programming", "python", "rust", "go", "javascript"], "Dev"),
            (["ml", "ai", "data science", "machine learning"], "ML"),
            (["audio", "music", "mix", "synth", "sound"], "Audio"),
            (["wiki", "reference", "encyclopedia"], "Wikipedia"),
        ]

        guard let matched = categories.first(where: { group in
            group.tokens.contains(where: { query.contains($0) })
        }) else {
            return nil
        }

        let items = context.catalogItems.filter { $0.category == matched.name }.prefix(3)
        guard !items.isEmpty else {
            return nil
        }

        let lines = items.map { "• \($0.title) — \($0.subtitle)" }
        return """
        Offline \(matched.name) picks:
        \(lines.joined(separator: "\n"))
        """
    }

    private static func overviewReply(context: OfflineRoachBrainContext) -> String {
        let modelSummary = context.activeModelName ?? "the last synced model"
        let featuredSummary = context.featuredItem?.title ?? "the Apps catalog"
        let memoryTitle = context.vault?.roachBrain.first?.title ?? "your cached notes"

        return """
        Offline RoachBrain is still live on the phone.

        Last model: \(modelSummary)
        Next shelf: \(featuredSummary)
        Cached note: \(memoryTitle)
        """
    }

    private static func topCatalogMatches(
        for query: String,
        in items: [StoreAppItem],
        limit: Int
    ) -> [StoreAppItem] {
        let queryTerms = query
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .map { String($0) }
            .filter { $0.count > 2 }

        guard !queryTerms.isEmpty else {
            return Array(items.prefix(limit))
        }

        return items
            .map { item -> (StoreAppItem, Int) in
                let haystack = [
                    item.title,
                    item.subtitle,
                    item.summary,
                    item.category,
                    item.section,
                    item.includes.joined(separator: " "),
                ]
                    .joined(separator: " ")
                    .lowercased()

                let score = queryTerms.reduce(into: 0) { partial, term in
                    if haystack.contains(term) {
                        partial += item.title.lowercased().contains(term) ? 3 : 1
                    }
                }

                return (item, score)
            }
            .filter { $0.1 > 0 }
            .sorted { left, right in
                if left.1 == right.1 {
                    return left.0.title < right.0.title
                }
                return left.1 > right.1
            }
            .prefix(limit)
            .map(\.0)
    }
}

enum CompanionLaunchOptions {
    static let screenshotTab: CompanionTab? = {
        let value = ProcessInfo.processInfo.environment["ROACHNET_SCREENSHOT_TAB"]?.lowercased()
        switch value {
        case "chat":
            return .chat
        case "vault":
            return .vault
        case "apps":
            return .apps
        case "runtime":
            return .runtime
        default:
            return nil
        }
    }()

    static let forceDemoMode = ProcessInfo.processInfo.environment["ROACHNET_DEMO_MODE"] == "1"
}

enum CompanionDemoState {
    static let catalogItems: [StoreAppItem] = [
        StoreAppItem(
            id: "demo-base-atlas",
            title: "Base Atlas",
            subtitle: "Foundational road, terrain, and route shelf",
            category: "Map Regions",
            section: "Quick installs",
            size: "3.2 GB",
            status: "Essential",
            source: "RoachNet mirror",
            summary: "The first atlas lane for getting maps onto the paired Mac fast.",
            featured: true,
            accent: "magenta",
            machineFit: "Any Apple Silicon Mac",
            includes: ["Road tiles", "Terrain layers", "Starter region metadata"],
            installLabel: "Install to RoachNet",
            detailLabel: "Preview",
            detailUrl: nil,
            installIntent: StoreInstallIntent(values: [
                "action": "education-resource",
                "category": "maps",
                "resource": "base-atlas"
            ]),
            iconBand: "GRID",
            iconMonogram: "AT",
            iconFamily: "maps",
            iconAsset: nil
        ),
        StoreAppItem(
            id: "demo-medical-library",
            title: "Medical Library",
            subtitle: "Field care, treatment steps, and emergency references",
            category: "Medicine",
            section: "Quick installs",
            size: "67 MB",
            status: "Essential",
            source: "RoachNet mirror",
            summary: "A tight offline medicine shelf that lands fast and stays useful.",
            featured: false,
            accent: "green",
            machineFit: "Any Apple Silicon Mac",
            includes: ["Field medicine", "Trauma care", "Reference tables"],
            installLabel: "Install to RoachNet",
            detailLabel: "Preview",
            detailUrl: nil,
            installIntent: StoreInstallIntent(values: [
                "action": "education-resource",
                "category": "medicine",
                "resource": "medical-library"
            ]),
            iconBand: "MED",
            iconMonogram: "ML",
            iconFamily: "medicine",
            iconAsset: nil
        ),
        StoreAppItem(
            id: "demo-python-docs",
            title: "Python Docs",
            subtitle: "Language and stdlib docs beside the editor",
            category: "Dev",
            section: "Today picks",
            size: "410 MB",
            status: "Standard",
            source: "DevDocs",
            summary: "Python references tuned for the RoachNet Dev lane.",
            featured: false,
            accent: "blue",
            machineFit: "Any Apple Silicon Mac",
            includes: ["Language reference", "Stdlib docs", "Built-in module guides"],
            installLabel: "Install to RoachNet",
            detailLabel: "Preview",
            detailUrl: nil,
            installIntent: StoreInstallIntent(values: [
                "action": "education-resource",
                "category": "dev",
                "resource": "python-docs"
            ]),
            iconBand: "DEV",
            iconMonogram: "PY",
            iconFamily: "dev",
            iconAsset: nil
        ),
        StoreAppItem(
            id: "demo-foss-cooking",
            title: "FOSS Cooking",
            subtitle: "Open cooking guides and practical food prep",
            category: "Education",
            section: "Today picks",
            size: "540 MB",
            status: "Standard",
            source: "RoachNet mirror",
            summary: "A clean food lane for study, prep, and practical recipes.",
            featured: false,
            accent: "gold",
            machineFit: "Any Apple Silicon Mac",
            includes: ["Cooking guides", "Food prep notes", "Reference shelves"],
            installLabel: "Install to RoachNet",
            detailLabel: "Preview",
            detailUrl: nil,
            installIntent: StoreInstallIntent(values: [
                "action": "education-resource",
                "category": "education",
                "resource": "foss-cooking"
            ]),
            iconBand: "READ",
            iconMonogram: "FC",
            iconFamily: "education",
            iconAsset: nil
        ),
        StoreAppItem(
            id: "demo-roachclaw-studio",
            title: "RoachClaw Studio",
            subtitle: "Prompt packs and local-model setup notes",
            category: "Models",
            section: "Today picks",
            size: "1.1 GB",
            status: "Standard",
            source: "RoachNet",
            summary: "The fast RoachClaw expansion lane for a fresh install.",
            featured: false,
            accent: "purple",
            machineFit: "Apple Silicon 16 GB+",
            includes: ["Prompt packs", "Model notes", "Runtime guides"],
            installLabel: "Install to RoachNet",
            detailLabel: "Preview",
            detailUrl: nil,
            installIntent: StoreInstallIntent(values: [
                "action": "education-resource",
                "category": "models",
                "resource": "roachclaw-studio"
            ]),
            iconBand: "CLAW",
            iconMonogram: "AI",
            iconFamily: "models",
            iconAsset: nil
        ),
        StoreAppItem(
            id: "demo-wikipedia-reference",
            title: "Wikipedia Reference",
            subtitle: "Right-sized general reference shelf",
            category: "Wikipedia",
            section: "Today picks",
            size: "2.4 GB",
            status: "Comprehensive",
            source: "Kiwix",
            summary: "A broad knowledge shelf that makes the vault feel bigger fast.",
            featured: false,
            accent: "cyan",
            machineFit: "Apple Silicon 16 GB+",
            includes: ["General encyclopedia", "Topic lookups", "Reference browsing"],
            installLabel: "Install to RoachNet",
            detailLabel: "Preview",
            detailUrl: nil,
            installIntent: StoreInstallIntent(values: [
                "action": "education-resource",
                "category": "wikipedia",
                "resource": "wikipedia-reference"
            ]),
            iconBand: "WIKI",
            iconMonogram: "WK",
            iconFamily: "reference",
            iconAsset: nil
        ),
    ]

    static let sessionList: [CompanionChatSessionSummary] = [
        CompanionChatSessionSummary(
            rawID: FlexibleIdentifier("demo-session"),
            title: "RoachBrain sync",
            model: "qwen2.5-coder:7b",
            timestamp: Date().addingTimeInterval(-760)
        ),
        CompanionChatSessionSummary(
            rawID: FlexibleIdentifier("demo-runtime"),
            title: "Runtime notes",
            model: "qwen2.5-coder:7b",
            timestamp: Date().addingTimeInterval(-2_600)
        ),
    ]

    static let currentSession = CompanionChatSessionDetail(
        rawID: FlexibleIdentifier("demo-session"),
        title: "RoachBrain sync",
        model: "qwen2.5-coder:7b",
        timestamp: Date().addingTimeInterval(-760),
        messages: [
            CompanionChatMessage(
                rawID: FlexibleIdentifier("demo-assistant-1"),
                role: "assistant",
                content: "RoachClaw is live on your desktop. Runtime is healthy, Apps are install-ready, and the vault lane is indexed.",
                createdAt: Date().addingTimeInterval(-1_100)
            ),
            CompanionChatMessage(
                rawID: FlexibleIdentifier("demo-user-1"),
                role: "user",
                content: "What changed since my last session?",
                createdAt: Date().addingTimeInterval(-900)
            ),
            CompanionChatMessage(
                rawID: FlexibleIdentifier("demo-assistant-2"),
                role: "assistant",
                content: "Three new Apps shelves are ready, your companion bridge is linked, and the desktop lane recommends a 7B local model on this machine class.",
                createdAt: Date().addingTimeInterval(-760)
            ),
        ]
    )

    static let runtime = CompanionRuntimeSummary(
        systemInfo: CompanionSystemInfo(
            mem: CompanionMemoryInfo(
                total: 36_028_797_952,
                available: 18_901_245_952,
                swapused: 0
            ),
            os: CompanionOSInfo(
                hostname: nil,
                arch: "arm64",
                distro: "macOS"
            ),
            hardwareProfile: CompanionHardwareProfile(
                platformLabel: "Apple Silicon desktop",
                chipFamily: "M-class",
                recommendedModelClass: "7B local models with a faster cloud lane optional",
                notes: [
                    "Plenty of headroom for the default RoachClaw lane.",
                    "Apps installs can run while chat stays responsive.",
                    "Companion bridge is enabled for mobile control."
                ],
                warnings: []
            )
        ),
        providers: CompanionProviderEnvelope(
            providers: [
                "ollama": CompanionProviderStatus(
                    provider: "ollama",
                    available: true,
                    source: "contained",
                    baseUrl: "http://RoachNet:36434",
                    error: nil
                ),
                "openclaw": CompanionProviderStatus(
                    provider: "openclaw",
                    available: true,
                    source: "contained",
                    baseUrl: "http://RoachNet:13001",
                    error: nil
                ),
            ]
        ),
        roachClaw: CompanionRoachClawStatus(
            label: "RoachClaw",
            ready: true,
            error: nil,
            defaultModel: "qwen2.5-coder:7b",
            resolvedDefaultModel: "qwen2.5-coder:7b",
            installedModels: ["qwen2.5-coder:7b", "nomic-embed-text:latest"],
            ollama: CompanionProviderStatus(
                provider: "ollama",
                available: true,
                source: "contained",
                baseUrl: "http://RoachNet:36434",
                error: nil
            ),
            openclaw: CompanionProviderStatus(
                provider: "openclaw",
                available: true,
                source: "contained",
                baseUrl: "http://RoachNet:13001",
                error: nil
            )
        ),
        account: CompanionAccountStatus(
            linked: true,
            provider: "RoachNet Account",
            portalUrl: "https://accounts.roachnet.org/",
            accountId: "acct-demo-roach",
            email: "roach@local.lane",
            displayName: "Roach",
            status: "linked",
            settingsSyncEnabled: true,
            savedAppsSyncEnabled: true,
            hostedChatEnabled: true,
            aliasHost: "RoachNet",
            bridgeUrl: "https://bridge.roachtail.local/studio-mac",
            runtimeOrigin: "http://RoachNet:38111",
            linkedAt: Date().addingTimeInterval(-86_400),
            lastSeenAt: Date().addingTimeInterval(-180),
            lastUpdatedAt: Date().addingTimeInterval(-90),
            notes: [
                "This device is linked to the same account lane as the desktop build.",
                "Web chat, saved app picks, and future synced settings can follow the same contained stack."
            ]
        ),
        roachTail: CompanionRoachTailStatus(
            enabled: true,
            networkName: "RoachTail",
            deviceName: "Studio Mac",
            deviceId: "studio-mac",
            status: "connected",
            transportMode: "tailnet-relay",
            secureOverlay: true,
            relayHost: "relay.roachtail.local",
            advertisedUrl: "https://bridge.roachtail.local/studio-mac",
            runtimeOrigin: "http://RoachNet:38111",
            runtimeTunnelUrl: "https://bridge.roachtail.local/studio-mac",
            joinCode: "RT-7Q2H-CLAW",
            joinCodeExpiresAt: Date().addingTimeInterval(540),
            pairingPayload: #"{"schema":"roachnet.roachtail.v1","version":1,"networkName":"RoachTail","deviceName":"Studio Mac","deviceId":"studio-mac","joinCode":"RT-7Q2H-CLAW","joinCodeExpiresAt":"2026-04-07T12:00:00Z","bridgeUrl":"https://bridge.roachtail.local/studio-mac","runtimeOrigin":"http://RoachNet:38111","runtimeTunnelUrl":"https://bridge.roachtail.local/studio-mac","transportMode":"tailnet-relay","secureOverlay":true}"#,
            pairingIssuedAt: Date().addingTimeInterval(-60),
            lastUpdatedAt: Date().addingTimeInterval(-180),
            notes: [
                "RoachTail keeps your paired devices on a private control lane.",
                "RoachClaw chat and Apps installs can ride the same secure bridge.",
                "Exit-node support stays optional for future bigger network routing."
            ],
            peers: [
                CompanionRoachTailPeer(
                    id: "iphone-lane",
                    name: "RoachNet iPhone",
                    platform: "iOS",
                    status: "online",
                    endpoint: "RoachNet",
                    lastSeenAt: Date().addingTimeInterval(-42),
                    allowsExitNode: false,
                    tags: ["chat", "apps", "runtime"]
                ),
                CompanionRoachTailPeer(
                    id: "ipad-lane",
                    name: "RoachNet iPad",
                    platform: "iPadOS",
                    status: "standby",
                    endpoint: "RoachNet",
                    lastSeenAt: Date().addingTimeInterval(-1_240),
                    allowsExitNode: false,
                    tags: ["vault", "notes"]
                ),
            ]
        ),
        roachSync: CompanionRoachSyncStatus(
            enabled: true,
            provider: "Syncthing",
            networkName: "RoachSync",
            deviceName: "Studio Mac",
            deviceId: "studio-mac",
            status: "syncing",
            folderId: "roachnet-vault",
            folderPath: "~/RoachNet/storage/vault",
            guiUrl: "http://RoachNet:8384",
            apiUrl: "http://RoachNet:8384/rest",
            transportMode: "tailnet-relay",
            secureOverlay: true,
            notes: [
                "RoachSync keeps the RoachNet vault grouped under one sync lane instead of loose host folders.",
                "The relay-aware path keeps sync metadata aligned with the same private bridge RoachTail uses for control."
            ],
            peers: [
                CompanionRoachSyncPeer(
                    id: "sync-iphone",
                    name: "RoachNet iPhone",
                    deviceId: "iphone-lane",
                    status: "up-to-date",
                    lastSeenAt: Date().addingTimeInterval(-95)
                ),
                CompanionRoachSyncPeer(
                    id: "sync-ipad",
                    name: "RoachNet iPad",
                    deviceId: "ipad-lane",
                    status: "syncing",
                    lastSeenAt: Date().addingTimeInterval(-380)
                ),
            ],
            lastUpdatedAt: Date().addingTimeInterval(-110)
        ),
        services: [
            CompanionService(serviceName: "ollama", friendlyName: "Ollama", status: "Running", installed: true),
            CompanionService(serviceName: "openclaw", friendlyName: "OpenClaw", status: "Running", installed: true),
            CompanionService(serviceName: "catalog-sync", friendlyName: "Catalog sync", status: "Idle", installed: true),
        ],
        downloads: [
            CompanionDownloadJob(jobId: "job-devdocs", progress: 72, status: "Installing", filepath: "DevDocs · Python Docs"),
            CompanionDownloadJob(jobId: "job-atlas", progress: 34, status: "Downloading", filepath: "Base Atlas"),
        ],
        installedModels: [
            CompanionInstalledModel(name: "qwen2.5-coder:7b", size: 4_294_967_296),
            CompanionInstalledModel(name: "nomic-embed-text:latest", size: 274_726_912),
        ],
        issues: []
    )

    static let vault = CompanionVaultSummary(
        knowledgeFiles: [
            "RoachBrain/label-rollout-notes.md",
            "Dev/roacnet-companion-bridge.md",
            "Vault/maps/pacific-prep-checklist.md",
        ],
        siteArchives: [
            CompanionSiteArchive(
                slug: "studio-router-notes",
                title: "Studio router notes",
                sourceUrl: nil,
                entryUrl: nil,
                createdAt: Date().addingTimeInterval(-7_200),
                status: "ready",
                note: "Last save from the desktop vault."
            ),
            CompanionSiteArchive(
                slug: "offline-medical-shelf",
                title: "Offline medical shelf",
                sourceUrl: nil,
                entryUrl: nil,
                createdAt: Date().addingTimeInterval(-14_000),
                status: "ready",
                note: "Curated health references mirror."
            ),
        ],
        roachBrain: [
            RoachBrainMemorySummary(
                id: "rb-1",
                title: "Companion bridge",
                summary: "Phone lane stays token-gated and forwards Apps installs back to the desktop runtime.",
                source: "RoachBrain",
                tags: ["ios", "runtime", "bridge"],
                pinned: true,
                lastAccessedAt: Date().addingTimeInterval(-1_200)
            ),
            RoachBrainMemorySummary(
                id: "rb-2",
                title: "Store priority",
                summary: "Maps, medicine, dev docs, and model packs stay closest to first-launch installs.",
                source: "RoachBrain",
                tags: ["apps", "catalog"],
                pinned: false,
                lastAccessedAt: Date().addingTimeInterval(-4_200)
            ),
        ],
        atlasShelves: [
            CompanionVaultShelfItem(
                id: "great-lakes",
                title: "Great Lakes",
                detail: "Regional atlas pack ready for the paired desktop map shelf.",
                kind: "atlas",
                status: "Ready on shelf",
                actionLabel: "Open atlas",
                routePath: "/maps",
                installed: true
            ),
        ],
        studyShelves: [
            CompanionVaultShelfItem(
                id: "field-medicine",
                title: "Field Medicine",
                detail: "Offline study shelf mirrored from the desktop coursework lane.",
                kind: "study",
                status: "Ready · core",
                actionLabel: "Open study shelf",
                routePath: "/docs/home",
                installed: true
            ),
        ],
        referenceShelves: [
            CompanionVaultShelfItem(
                id: "wikipedia-mini",
                title: "Wikipedia Mini",
                detail: "Contained offline reference package for the paired reading lane.",
                kind: "reference",
                status: "Current reference",
                actionLabel: "Open reference",
                routePath: "/docs/home",
                installed: true
            ),
        ],
        issues: []
    )
}
