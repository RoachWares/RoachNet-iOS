import Foundation

struct FlexibleIdentifier: Codable, Hashable, Sendable {
    let rawValue: String

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            rawValue = stringValue
            return
        }

        if let intValue = try? container.decode(Int.self) {
            rawValue = String(intValue)
            return
        }

        if let doubleValue = try? container.decode(Double.self) {
            rawValue = String(Int(doubleValue))
            return
        }

        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported identifier format")
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum APIDateDecoder {
    nonisolated(unsafe) private static let iso8601WithFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    nonisolated(unsafe) private static let iso8601Formatter = ISO8601DateFormatter()

    static func decode(_ value: String) -> Date? {
        iso8601WithFractionalSeconds.date(from: value) ?? iso8601Formatter.date(from: value)
    }
}

extension KeyedDecodingContainer {
    func decodeLossyStringIfPresent(forKey key: Key) -> String? {
        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            return stringValue
        }

        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return String(intValue)
        }

        if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
            return String(doubleValue)
        }

        return nil
    }

    func decodeLossyDateIfPresent(forKey key: Key) -> Date? {
        if let stringValue = decodeLossyStringIfPresent(forKey: key) {
            return APIDateDecoder.decode(stringValue)
        }

        if let timestamp = try? decodeIfPresent(Double.self, forKey: key) {
            let normalized = timestamp > 1_000_000_000_000 ? timestamp / 1_000 : timestamp
            return Date(timeIntervalSince1970: normalized)
        }

        return nil
    }
}

struct APIErrorEnvelope: Decodable, Sendable {
    let error: String
}

struct CompanionIssue: Decodable, Identifiable, Hashable, Sendable {
    let path: String
    let error: String

    var id: String { "\(path)-\(error)" }
}

struct CompanionChatMessage: Decodable, Identifiable, Hashable, Sendable {
    let rawID: FlexibleIdentifier
    let role: String
    let content: String
    let createdAt: Date?

    var id: String { rawID.rawValue }

    enum CodingKeys: String, CodingKey {
        case id
        case role
        case content
        case createdAt
        case timestamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rawID = try container.decode(FlexibleIdentifier.self, forKey: .id)
        role = (try? container.decode(String.self, forKey: .role)) ?? "assistant"
        content = (try? container.decode(String.self, forKey: .content)) ?? ""
        createdAt = container.decodeLossyDateIfPresent(forKey: .createdAt)
            ?? container.decodeLossyDateIfPresent(forKey: .timestamp)
    }

    init(rawID: FlexibleIdentifier, role: String, content: String, createdAt: Date?) {
        self.rawID = rawID
        self.role = role
        self.content = content
        self.createdAt = createdAt
    }
}

struct CompanionChatSessionSummary: Decodable, Identifiable, Hashable, Sendable {
    let rawID: FlexibleIdentifier
    let title: String
    let model: String?
    let timestamp: Date?

    var id: String { rawID.rawValue }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case model
        case timestamp
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rawID = try container.decode(FlexibleIdentifier.self, forKey: .id)
        title = (try? container.decode(String.self, forKey: .title)) ?? "New Chat"
        model = try? container.decodeIfPresent(String.self, forKey: .model)
        timestamp = container.decodeLossyDateIfPresent(forKey: .timestamp)
    }

    init(rawID: FlexibleIdentifier, title: String, model: String?, timestamp: Date?) {
        self.rawID = rawID
        self.title = title
        self.model = model
        self.timestamp = timestamp
    }
}

struct CompanionChatSessionDetail: Decodable, Identifiable, Hashable, Sendable {
    let rawID: FlexibleIdentifier
    let title: String
    let model: String?
    let timestamp: Date?
    let messages: [CompanionChatMessage]

    var id: String { rawID.rawValue }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case model
        case timestamp
        case messages
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        rawID = try container.decode(FlexibleIdentifier.self, forKey: .id)
        title = (try? container.decode(String.self, forKey: .title)) ?? "New Chat"
        model = try? container.decodeIfPresent(String.self, forKey: .model)
        timestamp = container.decodeLossyDateIfPresent(forKey: .timestamp)
        messages = (try? container.decode([CompanionChatMessage].self, forKey: .messages)) ?? []
    }

    init(
        rawID: FlexibleIdentifier,
        title: String,
        model: String?,
        timestamp: Date?,
        messages: [CompanionChatMessage]
    ) {
        self.rawID = rawID
        self.title = title
        self.model = model
        self.timestamp = timestamp
        self.messages = messages
    }
}

struct CompanionSendMessageResponse: Decodable, Sendable {
    let session: CompanionChatSessionSummary
    let userMessage: CompanionChatMessage
    let assistantMessage: CompanionChatMessage
}

struct CompanionProviderStatus: Decodable, Hashable, Sendable {
    let provider: String?
    let available: Bool?
    let source: String?
    let baseUrl: String?
    let error: String?
}

struct CompanionProviderEnvelope: Decodable, Hashable, Sendable {
    let providers: [String: CompanionProviderStatus]
}

struct CompanionRoachClawStatus: Decodable, Hashable, Sendable {
    let label: String
    let ready: Bool?
    let error: String?
    let defaultModel: String?
    let resolvedDefaultModel: String?
    let installedModels: [String]?
    let ollama: CompanionProviderStatus?
    let openclaw: CompanionProviderStatus?
}

struct CompanionService: Decodable, Identifiable, Hashable, Sendable {
    let serviceName: String
    let friendlyName: String?
    let status: String?
    let installed: Bool?

    var id: String { serviceName }
}

struct CompanionDownloadJob: Decodable, Identifiable, Hashable, Sendable {
    let jobId: String
    let progress: Int?
    let status: String?
    let filepath: String?

    var id: String { jobId }
}

struct CompanionInstalledModel: Decodable, Identifiable, Hashable, Sendable {
    let name: String
    let size: Int64?

    var id: String { name }
}

struct CompanionActionResponse: Decodable, Hashable, Sendable {
    let success: Bool?
    let message: String?
}

struct CompanionHardwareProfile: Decodable, Hashable, Sendable {
    let platformLabel: String?
    let chipFamily: String?
    let recommendedModelClass: String?
    let notes: [String]?
    let warnings: [String]?
}

struct CompanionMemoryInfo: Decodable, Hashable, Sendable {
    let total: UInt64
    let available: UInt64?
    let swapused: Double?
}

struct CompanionOSInfo: Decodable, Hashable, Sendable {
    let hostname: String?
    let arch: String?
    let distro: String?
}

struct CompanionSystemInfo: Decodable, Hashable, Sendable {
    let mem: CompanionMemoryInfo?
    let os: CompanionOSInfo?
    let hardwareProfile: CompanionHardwareProfile?
}

struct CompanionRuntimeSummary: Decodable, Hashable, Sendable {
    let systemInfo: CompanionSystemInfo?
    let providers: CompanionProviderEnvelope
    let roachClaw: CompanionRoachClawStatus
    let services: [CompanionService]
    let downloads: [CompanionDownloadJob]
    let installedModels: [CompanionInstalledModel]
    let issues: [CompanionIssue]
}

struct CompanionSiteArchive: Decodable, Identifiable, Hashable, Sendable {
    let slug: String
    let title: String?
    let sourceUrl: String?
    let entryUrl: String?
    let createdAt: Date?
    let status: String?
    let note: String?

    var id: String { slug }

    enum CodingKeys: String, CodingKey {
        case slug
        case title
        case sourceUrl
        case entryUrl
        case createdAt
        case status
        case note
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        slug = (try? container.decode(String.self, forKey: .slug)) ?? UUID().uuidString
        title = try? container.decodeIfPresent(String.self, forKey: .title)
        sourceUrl = try? container.decodeIfPresent(String.self, forKey: .sourceUrl)
        entryUrl = try? container.decodeIfPresent(String.self, forKey: .entryUrl)
        createdAt = container.decodeLossyDateIfPresent(forKey: .createdAt)
        status = try? container.decodeIfPresent(String.self, forKey: .status)
        note = try? container.decodeIfPresent(String.self, forKey: .note)
    }
}

struct RoachBrainMemorySummary: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let summary: String
    let source: String
    let tags: [String]
    let pinned: Bool
    let lastAccessedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case summary
        case source
        case tags
        case pinned
        case lastAccessedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        title = (try? container.decode(String.self, forKey: .title)) ?? "RoachBrain note"
        summary = (try? container.decode(String.self, forKey: .summary)) ?? ""
        source = (try? container.decode(String.self, forKey: .source)) ?? "RoachBrain"
        tags = (try? container.decode([String].self, forKey: .tags)) ?? []
        pinned = (try? container.decode(Bool.self, forKey: .pinned)) ?? false
        lastAccessedAt = container.decodeLossyDateIfPresent(forKey: .lastAccessedAt)
    }
}

struct CompanionVaultSummary: Decodable, Hashable, Sendable {
    let knowledgeFiles: [String]
    let siteArchives: [CompanionSiteArchive]
    let roachBrain: [RoachBrainMemorySummary]
    let issues: [CompanionIssue]
}

struct CompanionBootstrapResponse: Decodable, Sendable {
    let appName: String
    let machineName: String
    let appsCatalogUrl: String
    let runtime: CompanionRuntimeSummary
    let vault: CompanionVaultSummary
    let sessions: [CompanionChatSessionSummary]
}

struct StoreCatalogResponse: Decodable, Sendable {
    let updatedAt: String
    let featuredId: String?
    let items: [StoreAppItem]
}

struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        intValue = nil
    }

    init?(intValue: Int) {
        stringValue = String(intValue)
        self.intValue = intValue
    }
}

struct StoreInstallIntent: Decodable, Hashable, Sendable {
    let values: [String: String]

    var action: String { values["action"] ?? "" }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        var collected: [String: String] = [:]

        for key in container.allKeys {
            if let stringValue = try? container.decode(String.self, forKey: key) {
                collected[key.stringValue] = stringValue
            } else if let intValue = try? container.decode(Int.self, forKey: key) {
                collected[key.stringValue] = String(intValue)
            } else if let boolValue = try? container.decode(Bool.self, forKey: key) {
                collected[key.stringValue] = boolValue ? "true" : "false"
            }
        }

        values = collected
    }
}

struct StoreAppItem: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let subtitle: String
    let category: String
    let section: String
    let size: String?
    let status: String?
    let source: String?
    let summary: String
    let featured: Bool?
    let accent: String?
    let machineFit: String?
    let includes: [String]
    let installLabel: String?
    let detailLabel: String?
    let detailUrl: String?
    let installIntent: StoreInstallIntent?
    let iconBand: String?
    let iconMonogram: String?
    let iconFamily: String?
    let iconAsset: String?
}

struct CompanionInstallResponse: Decodable, Sendable {
    let ok: Bool
    let action: String
}
