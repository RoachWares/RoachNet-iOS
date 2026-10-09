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
        case "home":
            return .home
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
            ),
            playbook: CompanionRoachClawPlaybook(
                schema: "org.roachnet.roachclaw.playbook.v1",
                source: "demo",
                updatedAt: nil,
                capabilities: [
                    "roachclaw-cookbook",
                    "roachclaw-quant-aware-fit",
                    "roachclaw-deep-research",
                    "roachclaw-model-compare",
                    "roachbrain-memory-skills-audit",
                    "roachclaw-provider-diagnostics",
                    "roachclaw-visual-reports",
                    "roachclaw-agent-run-monitor",
                    "roachclaw-contextual-side-panel",
                    "roachclaw-vault-navigator",
                    "roachclaw-agent-activity-monitor",
                    "roachclaw-orchestration-dashboard",
                    "roachclaw-session-board",
                    "roachclaw-model-bench",
                    "roachclaw-document-lab",
                    "roachclaw-theme-studio",
                    "roachclaw-assistant-crew",
                    "roachclaw-session-history",
                    "roachclaw-provider-routes",
                    "roachclaw-backup-restore",
                    "roachclaw-signatures",
                    "roachclaw-local-api-keys",
                    "roachclaw-user-cloud-provider-keys",
                    "roachclaw-scoped-tool-bridge",
                    "roachclaw-tls-overrides",
                    "roachclaw-upload-limits",
                    "roachclaw-service-health",
                    "roachbrain-memory-provider",
                    "roachclaw-provider-oauth",
                    "roachbrain-embedding-lanes",
                    "roachclaw-tool-policy",
                    "roachclaw-streaming-markdown",
                    "roachclaw-migration-document-tools",
                    "roachclaw-font-emoji-assets",
                    "roachclaw-housekeeping",
                ],
                referenceSource: CompanionRoachClawReferenceSource(
                    repository: "https://github.com/pewdiepie-archdaemon/odysseus",
                    commit: "d9ebdd6fbba31b5f3c2cbae90f650f183958660e",
                    latestSeenCommit: "d9ebdd6fbba31b5f3c2cbae90f650f183958660e",
                    posture: "reference-only-native-rewrite",
                    sourceKind: "github-upstream"
                ),
                featureGroups: [
                    CompanionRoachClawFeatureGroup(
                        id: "chat",
                        title: "Chat",
                        summary: "Sessions, streaming, presets, attachments, provider routes, and detached run replay.",
                        status: "native-ready",
                        nativeSurface: "RoachClaw",
                        capabilities: ["sessions", "streaming", "presets", "detached-runs"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "session-board",
                        title: "Session Board",
                        summary: "Native session history, run replay, transcript save/export, and context restore.",
                        status: "native-state",
                        nativeSurface: "RoachClaw",
                        capabilities: ["history", "replay", "transcripts", "restore"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "session-history",
                        title: "Session History",
                        summary: "Fork, compact, export, rename, archive, auto-sort, and restore conversations.",
                        status: "native-state",
                        nativeSurface: "RoachClaw",
                        capabilities: ["fork", "compact", "export", "auto-sort", "archive"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "agent-tools",
                        title: "Agent Tools",
                        summary: "Scoped tools, shell actions, file actions, MCP handoffs, and local tool cards.",
                        status: "native-ready",
                        nativeSurface: "RoachClaw",
                        capabilities: ["tools", "shell", "mcp", "tool-index"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "cookbook",
                        title: "Cookbook",
                        summary: "Hardware-aware model fit with quantized and MoE sizing, downloads, and serve plans.",
                        status: "native-ready",
                        nativeSurface: "Runtime",
                        capabilities: ["hardware-scan", "quant-aware-sizing", "moe-active-params", "model-packs"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "deep-research",
                        title: "Deep Research",
                        summary: "Source gathering, synthesis, citations, and vault-ready briefs.",
                        status: "native-ready",
                        nativeSurface: "RoachClaw",
                        capabilities: ["sources", "citations"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "compare",
                        title: "Compare",
                        summary: "Blind model comparison, scoring, reveal, and saved winners.",
                        status: "native-ready",
                        nativeSurface: "RoachClaw",
                        capabilities: ["blind-test", "scoreboard"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "model-bench",
                        title: "Model Bench",
                        summary: "Fit checks, side-by-side model tests, saved winners, and serve plans.",
                        status: "native-ready",
                        nativeSurface: "Runtime",
                        capabilities: ["fit-score", "blind-compare", "serve-plan", "winners"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "model-providers",
                        title: "Model Providers",
                        summary: "Probe endpoints, curate model routes, hide noise, and keep defaults explicit.",
                        status: "native-ready",
                        nativeSurface: "Runtime",
                        capabilities: ["endpoint-probes", "provider-routes", "defaults", "hide-list"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "documents",
                        title: "Documents",
                        summary: "Vault docs, PDF, ebook, rewrite, summarize, export, and read-aloud actions.",
                        status: "native-ready",
                        nativeSurface: "Vault",
                        capabilities: ["pdf", "ebook", "read-aloud"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "migration-document-tools",
                        title: "Migration + Document Tools",
                        summary: "Office imports, active docs, migration previews, validators, and output-tail classification.",
                        status: "native-state",
                        nativeSurface: "Vault + RoachClaw",
                        capabilities: ["office-docs", "active-docs", "migration-manifest", "validators"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "memory-skills",
                        title: "RoachBrain + Skills",
                        summary: "Persistent memory, compacted context, skills, audits, retrieval, and import/export.",
                        status: "native-ready",
                        nativeSurface: "RoachBrain",
                        capabilities: ["memory", "skills", "context-compaction", "audit"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "memory-provider",
                        title: "Memory Provider",
                        summary: "Provider-neutral memory with RoachBrain native memory always available.",
                        status: "native-state",
                        nativeSurface: "RoachBrain",
                        capabilities: ["provider-contract", "remember", "recall"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "embedding-lanes",
                        title: "Embedding Lanes",
                        summary: "Separate local and custom embedding metadata with dimensions, fingerprints, reset safety, and health.",
                        status: "native-state",
                        nativeSurface: "RoachBrain",
                        capabilities: ["local-lane", "custom-lane", "fingerprints", "safe-reset"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "email",
                        title: "Mail",
                        summary: "Inbox triage, summaries, reply drafts, and account-scoped routing.",
                        status: "planned-native",
                        nativeSurface: "RoachClaw",
                        capabilities: ["triage", "drafts"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "notes-tasks",
                        title: "Notes + Tasks",
                        summary: "Notes, reminders, scheduled tasks, and delivery channels.",
                        status: "planned-native",
                        nativeSurface: "Home",
                        capabilities: ["notes", "reminders"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "calendar",
                        title: "Calendar",
                        summary: "Calendar planning, recurrence, reminders, and optional CalDAV sync.",
                        status: "planned-native",
                        nativeSurface: "Maps",
                        capabilities: ["calendar", "caldav"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "search-rag",
                        title: "Search + RAG",
                        summary: "Vault indexing, search provider routing, ranking, and source-grounded answers.",
                        status: "native-ready",
                        nativeSurface: "Vault",
                        capabilities: ["index", "ranking"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "voice",
                        title: "Voice",
                        summary: "Dictation, transcription, read-aloud, voices, and model packs.",
                        status: "native-ready",
                        nativeSurface: "RoachSpeech",
                        capabilities: ["stt", "tts"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "gallery-editor",
                        title: "Gallery + Editor",
                        summary: "Media import, albums, metadata tags, image cleanup, and asset export.",
                        status: "planned-native",
                        nativeSurface: "Vault",
                        capabilities: ["gallery", "tags"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "security",
                        title: "Security + Accounts",
                        summary: "Token gates, scoped tools, action approval, and local-first runtime posture.",
                        status: "native-ready",
                        nativeSurface: "Settings",
                        capabilities: ["tokens", "approval"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "provider-security",
                        title: "Provider Security",
                        summary: "TLS metadata, upload caps, OAuth flow state, and scoped provider handoffs.",
                        status: "native-state",
                        nativeSurface: "Settings",
                        capabilities: ["tls", "uploads", "oauth", "scoped-tools"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "tool-policy",
                        title: "Tool Policy",
                        summary: "Guide-only detection, disabled tools, hidden tools, and enforcement metadata.",
                        status: "native-state",
                        nativeSurface: "RoachClaw",
                        capabilities: ["guide-only", "disabled-tools", "hidden-tools", "enforcement"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "mobile",
                        title: "iOS Companion",
                        summary: "Runtime checks, vault reads, app installs, RoachTail pairing, and mobile controls.",
                        status: "native-ready",
                        nativeSurface: "iOS",
                        capabilities: ["runtime", "vault", "roachtail"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "diagnostics",
                        title: "Diagnostics",
                        summary: "Provider probes, runtime health, setup warnings, and degraded-state reporting.",
                        status: "native-ready",
                        nativeSurface: "Runtime",
                        capabilities: ["probes", "service-health-rollup", "secret-safe-probes", "bounded-timeouts", "warnings"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "contacts",
                        title: "Contacts",
                        summary: "Reply recipients, contact context, and ownership-scoped relationship hints.",
                        status: "planned-native",
                        nativeSurface: "RoachClaw",
                        capabilities: ["contacts", "recipients"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "webhooks-integrations",
                        title: "Hooks + Integrations",
                        summary: "Provider routes, webhooks, tokens, and scoped external handoffs.",
                        status: "planned-native",
                        nativeSurface: "Runtime",
                        capabilities: ["webhooks", "tokens"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "theme-studio",
                        title: "Theme Studio",
                        summary: "Palette, density, motion, and appearance controls owned by the native shell.",
                        status: "native-ready",
                        nativeSurface: "Settings",
                        capabilities: ["palette", "density", "motion", "contrast"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "visual-reports",
                        title: "Visual Reports",
                        summary: "Source evidence, rendered briefs, and vault-ready exports.",
                        status: "planned-native",
                        nativeSurface: "Vault",
                        capabilities: ["reports", "exports"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "orchestration",
                        title: "Orchestration",
                        summary: "Agent roles, context budgets, handoffs, and Activity Monitor-style run visibility.",
                        status: "native-state",
                        nativeSurface: "RoachClaw",
                        capabilities: ["agent-runs", "context-budgets", "handoffs", "activity-monitor"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "assistant-crew",
                        title: "Assistant Crew",
                        summary: "Recurring check-ins, scoped roles, run-now controls, and status ledgers.",
                        status: "native-state",
                        nativeSurface: "RoachClaw",
                        capabilities: ["crew-settings", "check-ins", "run-now", "status-ledger"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "signatures",
                        title: "Signatures",
                        summary: "Saved signatures for documents, mail drafts, and vault notes.",
                        status: "native-state",
                        nativeSurface: "Vault",
                        capabilities: ["signature-store", "document-signing", "mail-signatures"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "backup-restore",
                        title: "Backup + Restore",
                        summary: "Snapshot local lanes, scrub secrets, export state, and restore deliberately.",
                        status: "native-state",
                        nativeSurface: "Settings",
                        capabilities: ["export", "import", "scrub", "snapshots"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "local-api-keys",
                        title: "Local API Keys",
                        summary: "One-time reveal, hashed storage, owner scope, and revoke controls for local integrations.",
                        status: "native-state",
                        nativeSurface: "Settings",
                        capabilities: ["one-time-reveal", "hash-only-storage", "revoke"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "font-emoji-assets",
                        title: "Font + Emoji Assets",
                        summary: "Offline font discovery and emoji rendering for the native shell.",
                        status: "native-ready",
                        nativeSurface: "RoachNet",
                        capabilities: ["fonts", "emoji", "offline-assets"]
                    ),
                    CompanionRoachClawFeatureGroup(
                        id: "housekeeping",
                        title: "Housekeeping",
                        summary: "Cleanup previews, upload cleanup, rate limits, degraded-state checks, and safe reset paths.",
                        status: "native-state",
                        nativeSurface: "Runtime",
                        capabilities: ["cleanup", "rate-limits", "degraded-state", "reset-gates"]
                    ),
                ],
                referenceInventory: CompanionRoachClawReferenceInventory(
                    schema: "org.roachnet.roachclaw.github-reference-inventory.v1",
                    repository: "https://github.com/pewdiepie-archdaemon/odysseus",
                    commit: "d9ebdd6fbba31b5f3c2cbae90f650f183958660e",
                    latestSeenCommit: "d9ebdd6fbba31b5f3c2cbae90f650f183958660e",
                    sourceKind: "github-upstream",
                    observedFileCount: 1141,
                    functionalFileCount: 416,
                    coverageGroups: [
                        CompanionRoachClawReferenceInventoryGroup(
                            id: "routes",
                            label: "Routes + Helpers",
                            prefix: "routes/",
                            fileCount: 54,
                            nativeSurface: "Native API + Swift surfaces",
                            status: "tracked-native-rewrite",
                            notes: "Every route and route helper is treated as a RoachNet bridge, view, or operation contract."
                        ),
                        CompanionRoachClawReferenceInventoryGroup(
                            id: "core",
                            label: "Core Runtime",
                            prefix: "core/",
                            fileCount: 10,
                            nativeSurface: "Runtime + Settings",
                            status: "tracked-native-rewrite",
                            notes: "Auth, database, sessions, platform behavior, exceptions, and constants map to the contained runtime."
                        ),
                        CompanionRoachClawReferenceInventoryGroup(
                            id: "source",
                            label: "Source Modules",
                            prefix: "src/",
                            fileCount: 108,
                            nativeSurface: "RoachClaw + RoachBrain + Vault",
                            status: "tracked-native-rewrite",
                            notes: "Agent loops, tools, RAG, documents, settings scrub, uploads, and reports are native feature obligations."
                        ),
                        CompanionRoachClawReferenceInventoryGroup(
                            id: "services",
                            label: "Services",
                            prefix: "services/",
                            fileCount: 40,
                            nativeSurface: "Runtime + RoachSpeech + Vault",
                            status: "tracked-native-rewrite",
                            notes: "Docs, model fit, memory, research, search, shell, STT, TTS, and media services become RoachNet-native lanes."
                        ),
                        CompanionRoachClawReferenceInventoryGroup(
                            id: "mcp-servers",
                            label: "MCP Servers",
                            prefix: "mcp_servers/",
                            fileCount: 5,
                            nativeSurface: "RoachClaw Tools",
                            status: "tracked-native-rewrite",
                            notes: "Email, image generation, memory, and RAG MCP behavior maps to scoped native tools."
                        ),
                        CompanionRoachClawReferenceInventoryGroup(
                            id: "scripts",
                            label: "CLI Scripts",
                            prefix: "scripts/",
                            fileCount: 43,
                            nativeSurface: "Command Deck + Runtime",
                            status: "tracked-native-rewrite",
                            notes: "Operational scripts become command palette actions, runtime jobs, or documented non-shipping migration references."
                        ),
                        CompanionRoachClawReferenceInventoryGroup(
                            id: "companion",
                            label: "Companion Pairing",
                            prefix: "companion/",
                            fileCount: 4,
                            nativeSurface: "RoachNet iOS + RoachTail",
                            status: "tracked-native-rewrite",
                            notes: "Pairing and companion routes map to the iOS app and RoachTail local control plane."
                        ),
                        CompanionRoachClawReferenceInventoryGroup(
                            id: "static-js",
                            label: "Web Interaction Modules",
                            prefix: "static/js/",
                            fileCount: 152,
                            nativeSurface: "SwiftUI + RoachClaw Web",
                            status: "tracked-native-rewrite",
                            notes: "WebUI interaction behavior is rebuilt in SwiftUI or folded into the RoachClaw web surface."
                        ),
                    ],
                    nonShippingPolicy: "Python, Flask, WebUI, shell scripts, Docker, tests, and docs are reference material only; RoachNet ships native SwiftUI, Core ML, Foundation, AVFoundation, Network, and contained runtime rewrites."
                ),
                referenceModules: [
                    CompanionRoachClawReferenceModule(
                        id: "diagnostics-routes",
                        category: "route",
                        source: "routes/diagnostics_routes.py",
                        nativeSurface: "Runtime",
                        status: "native-ready"
                    ),
                    CompanionRoachClawReferenceModule(
                        id: "webhook-routes",
                        category: "route",
                        source: "routes/webhook_routes.py",
                        nativeSurface: "Runtime",
                        status: "planned-native"
                    ),
                    CompanionRoachClawReferenceModule(
                        id: "assistant-routes",
                        category: "route",
                        source: "routes/assistant_routes.py",
                        nativeSurface: "RoachClaw",
                        status: "native-state"
                    ),
                    CompanionRoachClawReferenceModule(
                        id: "api-token-routes",
                        category: "route",
                        source: "routes/api_token_routes.py",
                        nativeSurface: "Settings",
                        status: "native-state"
                    ),
                    CompanionRoachClawReferenceModule(
                        id: "agent-filesystem-tools",
                        category: "source",
                        source: "src/agent_tools/filesystem_tools.py",
                        nativeSurface: "Dev + Vault",
                        status: "native-ready"
                    ),
                    CompanionRoachClawReferenceModule(
                        id: "service-health",
                        category: "source",
                        source: "src/service_health.py",
                        nativeSurface: "Runtime",
                        status: "native-state"
                    ),
                    CompanionRoachClawReferenceModule(
                        id: "stt-routes",
                        category: "route",
                        source: "routes/stt_routes.py",
                        nativeSurface: "RoachSpeech",
                        status: "native-ready"
                    ),
                    CompanionRoachClawReferenceModule(
                        id: "tts-routes",
                        category: "route",
                        source: "routes/tts_routes.py",
                        nativeSurface: "RoachSpeech",
                        status: "native-ready"
                    ),
                    CompanionRoachClawReferenceModule(
                        id: "visual-report",
                        category: "source",
                        source: "src/visual_report.py",
                        nativeSurface: "Vault",
                        status: "planned-native"
                    ),
                    CompanionRoachClawReferenceModule(
                        id: "agent-runs",
                        category: "source",
                        source: "src/agent_runs.py",
                        nativeSurface: "RoachClaw",
                        status: "native-state"
                    ),
                    CompanionRoachClawReferenceModule(
                        id: "embedding-lanes",
                        category: "source",
                        source: "src/embedding_lanes.py",
                        nativeSurface: "RoachBrain",
                        status: "native-state"
                    ),
                    CompanionRoachClawReferenceModule(
                        id: "tool-policy",
                        category: "source",
                        source: "src/tool_policy.py",
                        nativeSurface: "RoachClaw",
                        status: "native-state"
                    ),
                    CompanionRoachClawReferenceModule(
                        id: "event-bus",
                        category: "source",
                        source: "src/event_bus.py",
                        nativeSurface: "Runtime",
                        status: "native-state"
                    ),
                    CompanionRoachClawReferenceModule(
                        id: "settings-source",
                        category: "source",
                        source: "src/settings.py",
                        nativeSurface: "Settings",
                        status: "native-ready"
                    ),
                    CompanionRoachClawReferenceModule(
                        id: "hwfit-fit",
                        category: "service",
                        source: "services/hwfit/fit.py",
                        nativeSurface: "Runtime",
                        status: "native-ready"
                    ),
                    CompanionRoachClawReferenceModule(
                        id: "streaming-segmenter",
                        category: "static-js",
                        source: "static/js/streamingSegmenter.js",
                        nativeSurface: "RoachClaw Web",
                        status: "native-state"
                    ),
                    CompanionRoachClawReferenceModule(
                        id: "streaming-renderer",
                        category: "static-js",
                        source: "static/js/streamingRenderer.js",
                        nativeSurface: "RoachClaw Web",
                        status: "native-state"
                    ),
                ],
                lanes: [
                    CompanionRoachClawPlaybookLane(
                        id: "session-board",
                        title: "Session Board",
                        summary: "Keep chats, runs, replay crumbs, and context in one native lane.",
                        status: "native-state",
                        icon: "rectangle.stack.badge.person.crop",
                        accent: "cyan",
                        localFirst: true,
                        actions: ["Open sessions", "Resume run"]
                    ),
                    CompanionRoachClawPlaybookLane(
                        id: "model-bench",
                        title: "Model Bench",
                        summary: "Fit, compare, and save the model that deserves the job.",
                        status: "native-ready",
                        icon: "slider.horizontal.below.rectangle",
                        accent: "magenta",
                        localFirst: true,
                        actions: ["Fit model", "Run compare"]
                    ),
                    CompanionRoachClawPlaybookLane(
                        id: "cookbook",
                        title: "RoachClaw Cookbook",
                        summary: "Pick the model lane that actually fits this Mac.",
                        status: "ready",
                        icon: "cpu",
                        accent: "green",
                        localFirst: true,
                        actions: ["Scan hardware", "Recommend a model"]
                    ),
                    CompanionRoachClawPlaybookLane(
                        id: "deep-research",
                        title: "Deep Research",
                        summary: "Collect sources and turn them into a clean vault brief.",
                        status: "ready",
                        icon: "doc.text.magnifyingglass",
                        accent: "cyan",
                        localFirst: true,
                        actions: ["Plan questions", "Write brief"]
                    ),
                    CompanionRoachClawPlaybookLane(
                        id: "compare",
                        title: "Compare",
                        summary: "Blind-test model answers before trusting the loud one.",
                        status: "ready",
                        icon: "rectangle.split.2x1",
                        accent: "magenta",
                        localFirst: true,
                        actions: ["Run A/B prompt", "Save winner"]
                    ),
                    CompanionRoachClawPlaybookLane(
                        id: "theme-studio",
                        title: "Theme Studio",
                        summary: "Tune shell density, motion, palette, and contrast.",
                        status: "native-ready",
                        icon: "paintpalette",
                        accent: "bronze",
                        localFirst: true,
                        actions: ["Switch density", "Preview theme"]
                    ),
                    CompanionRoachClawPlaybookLane(
                        id: "memory-skills",
                        title: "RoachBrain Audit",
                        summary: "Keep useful procedures, compact important context, and retire stale cruft.",
                        status: "ready",
                        icon: "brain.head.profile",
                        accent: "bronze",
                        localFirst: true,
                        actions: ["Audit skills", "Compact context"]
                    ),
                    CompanionRoachClawPlaybookLane(
                        id: "agent-monitor",
                        title: "Agent Monitor",
                        summary: "Track local runs, replay crumbs, tool cards, and event counters.",
                        status: "native-ready",
                        icon: "bolt.badge.clock",
                        accent: "green",
                        localFirst: true,
                        actions: ["Review runs", "Check tools"]
                    ),
                    CompanionRoachClawPlaybookLane(
                        id: "orchestration",
                        title: "Orchestration",
                        summary: "Stage agent roles, handoffs, context budgets, and finish lines.",
                        status: "native-state",
                        icon: "rectangle.3.group",
                        accent: "cyan",
                        localFirst: true,
                        actions: ["Assign roles", "Track handoffs"]
                    ),
                    CompanionRoachClawPlaybookLane(
                        id: "assistant-crew",
                        title: "Assistant Crew",
                        summary: "Recurring check-ins, scoped roles, and run-now status without hiding a daemon.",
                        status: "native-state",
                        icon: "person.3.sequence",
                        accent: "bronze",
                        localFirst: true,
                        actions: ["Create check-in", "Run now"]
                    ),
                    CompanionRoachClawPlaybookLane(
                        id: "service-health",
                        title: "Service Health",
                        summary: "Roll up runtime, memory, embeddings, intake, tools, services, and updates.",
                        status: "native-state",
                        icon: "waveform.path.ecg.rectangle",
                        accent: "green",
                        localFirst: true,
                        actions: ["Run health", "Copy safe report"]
                    ),
                    CompanionRoachClawPlaybookLane(
                        id: "migration-document-tools",
                        title: "Migration + Document Tools",
                        summary: "Office imports, active docs, migration previews, route validators, and cookbook output tails.",
                        status: "native-state",
                        icon: "doc.badge.gearshape",
                        accent: "cyan",
                        localFirst: true,
                        actions: ["Import doc", "Preview migration"]
                    ),
                    CompanionRoachClawPlaybookLane(
                        id: "backup-restore",
                        title: "Backup + Restore",
                        summary: "Snapshot local RoachClaw state and inspect the scrubbed export.",
                        status: "native-state",
                        icon: "externaldrive.badge.timemachine",
                        accent: "cyan",
                        localFirst: true,
                        actions: ["Create snapshot", "Inspect export"]
                    ),
                ]
            ),
            operations: CompanionRoachClawOperations(
                schema: "org.roachnet.roachclaw.operations.v1",
                updatedAt: nil,
                diagnostics: CompanionRoachClawOperations.Diagnostics(
                    status: "ready",
                    probes: [
                        CompanionRoachClawOperations.Probe(
                            id: "roachclaw-native-agent",
                            label: "RoachClaw native agent",
                            available: true,
                            detail: "Native agent lane is available on the paired Mac."
                        ),
                        CompanionRoachClawOperations.Probe(
                            id: "ollama",
                            label: "Local model lane",
                            available: true,
                            detail: "Local model runner is reachable."
                        ),
                    ],
                    warnings: []
                ),
                serviceHealth: CompanionRoachClawOperations.CollectionLane(
                    status: "ok",
                    storagePath: nil,
                    count: 9,
                    open: nil,
                    messages: nil,
                    drafts: nil,
                    active: 8,
                    route: "roachnet://runtime/service-health",
                    summaryItems: ["Local model lane: ok", "RoachClaw native agent: ok", "Intake policy: ok", "Updates: ok"],
                    detail: "Secret-safe health report for model runner, native agent, memory, embeddings, intake, services, tools, and updates.",
                    actions: ["Run service health", "Inspect degraded lanes", "Copy safe report"]
                ),
                contacts: CompanionRoachClawOperations.Contacts(
                    status: "local-first",
                    storagePath: "~/RoachNet/storage/vault/roachclaw/contacts.json",
                    recordCount: 0,
                    scopes: ["local-address-book", "reply-recipient-context"],
                    notes: ["Contact context stays local to the paired Mac."]
                ),
                hooks: CompanionRoachClawOperations.Hooks(
                    status: "armed-local-only",
                    storagePath: "~/RoachNet/storage/vault/roachclaw/hooks.json",
                    endpoints: [
                        CompanionRoachClawOperations.HookEndpoint(
                            id: "agent-run",
                            method: "POST",
                            path: "/api/roachclaw/agent/run",
                            scope: "approval-gated-agent-run"
                        )
                    ],
                    secretsPolicy: "local-redacted"
                ),
                jobs: CompanionRoachClawOperations.Jobs(
                    status: "idle",
                    scheduler: CompanionRoachClawOperations.Scheduler(
                        status: "local-queue",
                        storagePath: "~/RoachNet/storage/vault/roachclaw/jobs.json",
                        pending: 0
                    )
                ),
                notesTasks: CompanionRoachClawOperations.CollectionLane(
                    status: "empty",
                    storagePath: "~/RoachNet/storage/vault/roachclaw/tasks.json",
                    count: 0,
                    open: 0,
                    messages: nil,
                    drafts: nil,
                    active: nil
                ),
                calendar: CompanionRoachClawOperations.CollectionLane(
                    status: "empty",
                    storagePath: "~/RoachNet/storage/vault/roachclaw/calendar.json",
                    count: 0,
                    open: nil,
                    messages: nil,
                    drafts: nil,
                    active: nil
                ),
                reports: CompanionRoachClawOperations.Reports(
                    status: "ready",
                    root: "~/RoachNet/storage/vault/roachclaw/reports",
                    formats: ["markdown", "json", "pdf-ready-html"],
                    templates: ["research-brief", "model-compare", "diagnostics-report"],
                    count: 0
                ),
                memories: CompanionRoachClawOperations.CollectionLane(
                    status: "empty",
                    storagePath: "~/RoachNet/storage/vault/roachclaw/memories.json",
                    count: 0,
                    open: nil,
                    messages: nil,
                    drafts: nil,
                    active: nil
                ),
                skills: CompanionRoachClawOperations.CollectionLane(
                    status: "empty",
                    storagePath: "~/RoachNet/storage/vault/roachclaw/skills.json",
                    count: 0,
                    open: nil,
                    messages: nil,
                    drafts: nil,
                    active: nil
                ),
                editorDrafts: CompanionRoachClawOperations.CollectionLane(
                    status: "empty",
                    storagePath: "~/RoachNet/storage/vault/roachclaw/editor-drafts.json",
                    count: 0,
                    open: 0,
                    messages: nil,
                    drafts: nil,
                    active: nil
                ),
                migrationDocumentTools: CompanionRoachClawOperations.CollectionLane(
                    status: "native-state",
                    storagePath: "~/RoachNet/storage/vault/roachclaw/migration-document-tools.json",
                    count: 10,
                    open: nil,
                    messages: nil,
                    drafts: nil,
                    active: 6,
                    route: "roachnet://vault/document-tools",
                    summaryItems: ["Office docs become vault docs", "agent imports preview first", "SSH targets validated"],
                    detail: "Native Office import, active document context, migration manifest previews, validators, and cookbook output classification.",
                    actions: ["Import Office doc", "Preview migration", "Validate target", "Classify output"]
                ),
                searchCache: CompanionRoachClawOperations.CollectionLane(
                    status: "empty",
                    storagePath: "~/RoachNet/storage/vault/roachclaw/search-cache.json",
                    count: 0,
                    open: nil,
                    messages: nil,
                    drafts: nil,
                    active: nil
                ),
                gallery: CompanionRoachClawOperations.CollectionLane(
                    status: "empty",
                    storagePath: "~/RoachNet/storage/vault/roachclaw/gallery.json",
                    count: 0,
                    open: nil,
                    messages: nil,
                    drafts: nil,
                    active: nil
                ),
                webhooks: CompanionRoachClawOperations.CollectionLane(
                    status: "empty",
                    storagePath: "~/RoachNet/storage/vault/roachclaw/webhooks.json",
                    count: 0,
                    open: nil,
                    messages: nil,
                    drafts: nil,
                    active: 0
                ),
                agentRuns: CompanionRoachClawOperations.CollectionLane(
                    status: "empty",
                    storagePath: "~/RoachNet/storage/vault/roachclaw/agent-runs.json",
                    count: 0,
                    open: nil,
                    messages: nil,
                    drafts: nil,
                    active: 0
                ),
                contextCompactions: CompanionRoachClawOperations.CollectionLane(
                    status: "empty",
                    storagePath: "~/RoachNet/storage/vault/roachclaw/context-compactions.json",
                    count: 0,
                    open: nil,
                    messages: nil,
                    drafts: nil,
                    active: nil
                ),
                toolIndex: CompanionRoachClawOperations.CollectionLane(
                    status: "empty",
                    storagePath: "~/RoachNet/storage/vault/roachclaw/tool-index.json",
                    count: 0,
                    open: nil,
                    messages: nil,
                    drafts: nil,
                    active: 0
                ),
                events: CompanionRoachClawOperations.CollectionLane(
                    status: "empty",
                    storagePath: "~/RoachNet/storage/vault/roachclaw/events.json",
                    count: 0,
                    open: nil,
                    messages: nil,
                    drafts: nil,
                    active: 0
                ),
                commandDeck: CompanionRoachClawOperations.CollectionLane(
                    status: "ready",
                    storagePath: nil,
                    count: 0,
                    open: nil,
                    messages: nil,
                    drafts: nil,
                    active: 0,
                    priority: "prime",
                    route: "roachnet://command",
                    hotkey: "Ctrl-Cmd-R",
                    summaryItems: ["0 armed tools", "0 skills", "0 presets", "0 hooks"],
                    detail: "Raycast-style command surface backed by local tool cards, skills, presets, and scoped hooks.",
                    actions: ["Search commands", "Preview context", "Run with approval", "Pin useful actions"]
                ),
                contextRail: CompanionRoachClawOperations.CollectionLane(
                    status: "empty",
                    storagePath: nil,
                    count: 0,
                    open: 0,
                    messages: nil,
                    drafts: nil,
                    active: nil,
                    priority: "empty",
                    route: "roachnet://roachclaw/context",
                    hotkey: "Cmd-Shift-C",
                    summaryItems: ["0 memories", "0 compactions", "0 crumbs", "0 drafts"],
                    detail: "Cursor-style side rail for memories, compactions, search crumbs, and editable drafts.",
                    actions: ["Show visible context", "Compact thread", "Attach vault crumb", "Save working note"]
                ),
                vaultNavigator: CompanionRoachClawOperations.CollectionLane(
                    status: "empty",
                    storagePath: nil,
                    count: 0,
                    open: nil,
                    messages: nil,
                    drafts: nil,
                    active: 0,
                    priority: "feed",
                    route: "roachnet://vault",
                    hotkey: "Cmd-Shift-V",
                    summaryItems: ["0 assets", "0 reports", "0 source crumbs", "0 drafts"],
                    detail: "Finder-like local navigator for vault assets, report outputs, source crumbs, and staged drafts.",
                    actions: ["Browse vault", "Preview asset", "Reveal path", "Drop files into shelf"]
                ),
                agentMonitor: CompanionRoachClawOperations.CollectionLane(
                    status: "idle",
                    storagePath: nil,
                    count: 0,
                    open: nil,
                    messages: nil,
                    drafts: nil,
                    active: 0,
                    stalled: 0,
                    priority: "idle",
                    route: "roachnet://roachclaw/runs",
                    hotkey: "Cmd-Shift-M",
                    summaryItems: ["0 running", "0 stalled", "0 counters", "0 tools"],
                    detail: "Activity Monitor-style view of autonomous RoachClaw runs, replay crumbs, and local event pressure.",
                    actions: ["Inspect run", "Stop noisy work", "Replay events", "Collect evidence"]
                ),
                orchestrationDashboard: CompanionRoachClawOperations.CollectionLane(
                    status: "ready",
                    storagePath: nil,
                    count: 0,
                    open: 0,
                    messages: nil,
                    drafts: nil,
                    active: 0,
                    priority: "ready",
                    route: "roachnet://roachclaw/orchestration",
                    hotkey: "Cmd-Shift-O",
                    summaryItems: ["0 runs", "0 open tasks", "0 calendar", "0 snapshots"],
                    detail: "Monet-style dashboard for local agent roles, context budgets, handoffs, and outcome ledgers.",
                    actions: ["Assign roles", "Set context budgets", "Track handoffs", "Publish outcome"]
                ),
                mail: CompanionRoachClawOperations.CollectionLane(
                    status: "empty",
                    storagePath: "~/RoachNet/storage/vault/roachclaw/mail.json",
                    count: 0,
                    open: nil,
                    messages: 0,
                    drafts: 0,
                    active: nil
                ),
                presets: CompanionRoachClawOperations.CollectionLane(
                    status: "empty",
                    storagePath: "~/RoachNet/storage/vault/roachclaw/presets.json",
                    count: 0,
                    open: nil,
                    messages: nil,
                    drafts: nil,
                    active: nil
                ),
                signatures: CompanionRoachClawOperations.CollectionLane(
                    status: "empty",
                    storagePath: "~/RoachNet/storage/vault/roachclaw/signatures.json",
                    count: 0,
                    open: nil,
                    messages: nil,
                    drafts: nil,
                    active: nil
                ),
                apiTokens: CompanionRoachClawOperations.CollectionLane(
                    status: "empty",
                    storagePath: "~/RoachNet/storage/vault/roachclaw/api-tokens.json",
                    count: 0,
                    open: nil,
                    messages: nil,
                    drafts: nil,
                    active: 0
                ),
                cloudProviders: CompanionRoachClawOperations.CollectionLane(
                    status: "local-default",
                    storagePath: "~/RoachNet/storage/vault/roachclaw/cloud-provider-keys.json",
                    count: 3,
                    open: nil,
                    messages: nil,
                    drafts: nil,
                    active: 0,
                    detail: "OpenAI, Anthropic, and OpenRouter stay optional user-owned routes."
                ),
                workspaceBrowser: CompanionRoachClawOperations.CollectionLane(
                    status: "ready",
                    storagePath: nil,
                    count: 0,
                    open: nil,
                    messages: nil,
                    drafts: nil,
                    active: nil,
                    route: "roachnet://dev/workspace",
                    hotkey: "Cmd-Shift-W",
                    summaryItems: ["directories only", "dotfiles hidden", "symlinks not followed"],
                    detail: "Browse project folders for Dev and RoachClaw context without handing navigation to a WebUI bridge.",
                    actions: ["Browse workspace", "Attach folder", "Pin project", "Send to RoachClaw"]
                ),
                userTime: CompanionRoachClawOperations.CollectionLane(
                    status: "system-default",
                    storagePath: "~/RoachNet/storage/vault/roachclaw/user-time.json",
                    count: 0,
                    open: nil,
                    messages: nil,
                    drafts: nil,
                    active: nil,
                    route: "roachnet://settings/time",
                    summaryItems: ["local timezone", "prompt clock"],
                    detail: "Timezone and local clock context for schedulers and relative-date prompts.",
                    actions: ["Set timezone", "Refresh clock context", "Attach to prompt"]
                ),
                cookbookServeLifecycle: CompanionRoachClawOperations.CollectionLane(
                    status: "idle",
                    storagePath: "~/RoachNet/storage/vault/roachclaw/cookbook-serve-schedules.json",
                    count: 0,
                    open: nil,
                    messages: nil,
                    drafts: nil,
                    active: 0,
                    queued: 0,
                    route: "roachnet://roachclaw/cookbook",
                    summaryItems: ["0 schedules", "0 active", "0 waiting"],
                    detail: "Model serve schedules with explicit stop windows and progress signals.",
                    actions: ["Schedule model", "Mirror calendar", "Stop expired serves", "Inspect progress"]
                ),
                scopedToolBridge: CompanionRoachClawOperations.CollectionLane(
                    status: "ready",
                    storagePath: "~/RoachNet/storage/vault/roachclaw/scoped-tool-bridge.json",
                    count: 13,
                    open: nil,
                    messages: nil,
                    drafts: nil,
                    active: 4,
                    route: "roachnet://roachclaw/tools",
                    summaryItems: ["cookbook:read", "memory:write", "documents:read", "email:draft"],
                    detail: "Scoped local tool bridge with explicit approval boundaries.",
                    actions: ["List scopes", "Inspect endpoints", "Require approval", "Export manifest"]
                ),
                tlsOverrides: CompanionRoachClawOperations.CollectionLane(
                    status: "default-trust",
                    storagePath: "~/RoachNet/storage/vault/roachclaw/tls-overrides.json",
                    count: 0,
                    open: nil,
                    messages: nil,
                    drafts: nil,
                    active: 0,
                    route: "roachnet://settings/provider-security",
                    summaryItems: ["llm-provider-probes-only", "system trust"],
                    detail: "Optional extra CA bundle metadata. Verification stays on.",
                    actions: ["Set CA bundle", "Clear override", "Inspect scope"]
                ),
                uploadLimits: CompanionRoachClawOperations.CollectionLane(
                    status: "enforced",
                    storagePath: nil,
                    count: 11,
                    open: nil,
                    messages: nil,
                    drafts: nil,
                    active: nil,
                    route: "roachnet://vault/imports",
                    summaryItems: ["JSON request body: 1 MB", "Chat attachment: 10 MB", "RoachSpeech audio: 25 MB", "Gallery import: 100 MB"],
                    detail: "One policy table bounds chat, vault, media, speech, calendar, and installer intake.",
                    actions: ["Inspect limits", "Retry smaller file", "Open intake policy"]
                ),
                memoryProvider: CompanionRoachClawOperations.CollectionLane(
                    status: "native-provider",
                    storagePath: "~/RoachNet/storage/vault/roachclaw/memory-provider.json",
                    count: 1,
                    open: nil,
                    messages: nil,
                    drafts: nil,
                    active: 1,
                    route: "roachnet://roachbrain/providers",
                    summaryItems: ["RoachBrain native memory"],
                    detail: "Provider-neutral memory contract with RoachBrain always available.",
                    actions: ["List providers", "Recall memory", "Write local memory", "Audit tools"]
                ),
                providerOAuth: CompanionRoachClawOperations.CollectionLane(
                    status: "idle",
                    storagePath: "~/RoachNet/storage/vault/roachclaw/provider-oauth.json",
                    count: 0,
                    open: nil,
                    messages: nil,
                    drafts: nil,
                    active: 0,
                    route: "roachnet://settings/provider-oauth",
                    summaryItems: [],
                    detail: "User-owned remote tool auth metadata. Tokens do not leave the paired Mac.",
                    actions: ["Start user flow", "Cancel pending flow", "Review scopes"]
                ),
                embeddingLanes: CompanionRoachClawOperations.CollectionLane(
                    status: "healthy",
                    storagePath: "~/RoachNet/storage/vault/roachclaw/embedding-lanes.json",
                    count: 2,
                    open: nil,
                    messages: nil,
                    drafts: nil,
                    active: 1,
                    route: "roachnet://roachbrain/embedding-lanes",
                    summaryItems: ["Custom: not-configured", "Local: 384d"],
                    detail: "Separate local and custom vector lanes with fingerprints, stats, and safe reset metadata.",
                    actions: ["Inspect lanes", "Check fingerprints", "Reset safely", "Reindex local memory"]
                ),
                toolPolicy: CompanionRoachClawOperations.CollectionLane(
                    status: "enforced",
                    storagePath: "~/RoachNet/storage/vault/roachclaw/tool-policy.json",
                    count: 44,
                    open: nil,
                    messages: nil,
                    drafts: nil,
                    active: 0,
                    route: "roachnet://roachclaw/tool-policy",
                    summaryItems: ["normal", "0 disabled", "0 hidden"],
                    detail: "Guide-only and disabled-tool state for native RoachClaw display.",
                    actions: ["Evaluate prompt", "Hide disabled tools", "Show enforcement reason", "Review scopes"]
                ),
                backups: CompanionRoachClawOperations.CollectionLane(
                    status: "ready",
                    storagePath: "~/RoachNet/storage/vault/roachclaw/backups.json",
                    count: 0,
                    open: nil,
                    messages: nil,
                    drafts: nil,
                    active: nil
                ),
                adminRecovery: CompanionRoachClawOperations.AdminRecovery(
                    status: "local-owner-required",
                    actions: ["first-run-owner-claim", "reset-local-agent-state"],
                    remoteAccess: false
                )
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
            CompanionService(serviceName: "roachnet_ollama", friendlyName: "RoachNet Chat (RoachInference)", status: "Running", installed: true),
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
