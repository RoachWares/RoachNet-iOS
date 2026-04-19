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

struct APIErrorEnvelope: Codable, Sendable {
    let error: String
}

struct CompanionIssue: Codable, Identifiable, Hashable, Sendable {
    let path: String
    let error: String

    var id: String { "\(path)-\(error)" }
}

struct CompanionChatMessage: Codable, Identifiable, Hashable, Sendable {
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

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rawID, forKey: .id)
        try container.encode(role, forKey: .role)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
    }
}

struct CompanionChatSessionSummary: Codable, Identifiable, Hashable, Sendable {
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

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rawID, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(model, forKey: .model)
        try container.encodeIfPresent(timestamp, forKey: .timestamp)
    }
}

struct CompanionChatSessionDetail: Codable, Identifiable, Hashable, Sendable {
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

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rawID, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(model, forKey: .model)
        try container.encodeIfPresent(timestamp, forKey: .timestamp)
        try container.encode(messages, forKey: .messages)
    }
}

struct CompanionSendMessageResponse: Codable, Sendable {
    let session: CompanionChatSessionSummary
    let userMessage: CompanionChatMessage
    let assistantMessage: CompanionChatMessage
}

struct CompanionProviderStatus: Codable, Hashable, Sendable {
    let provider: String?
    let available: Bool?
    let source: String?
    let baseUrl: String?
    let error: String?
}

struct CompanionProviderEnvelope: Codable, Hashable, Sendable {
    let providers: [String: CompanionProviderStatus]
}

struct CompanionRoachClawStatus: Codable, Hashable, Sendable {
    let label: String
    let ready: Bool?
    let error: String?
    let defaultModel: String?
    let resolvedDefaultModel: String?
    let installedModels: [String]?
    let ollama: CompanionProviderStatus?
    let openclaw: CompanionProviderStatus?
}

struct CompanionRoachTailPeer: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let platform: String
    let status: String
    let endpoint: String?
    let lastSeenAt: Date?
    let allowsExitNode: Bool?
    let tags: [String]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case platform
        case status
        case endpoint
        case lastSeenAt
        case allowsExitNode
        case tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        name = (try? container.decode(String.self, forKey: .name)) ?? "Linked device"
        platform = (try? container.decode(String.self, forKey: .platform)) ?? "device"
        status = (try? container.decode(String.self, forKey: .status)) ?? "linked"
        endpoint = try? container.decodeIfPresent(String.self, forKey: .endpoint)
        lastSeenAt = container.decodeLossyDateIfPresent(forKey: .lastSeenAt)
        allowsExitNode = try? container.decodeIfPresent(Bool.self, forKey: .allowsExitNode)
        tags = (try? container.decode([String].self, forKey: .tags)) ?? []
    }

    init(
        id: String,
        name: String,
        platform: String,
        status: String,
        endpoint: String?,
        lastSeenAt: Date?,
        allowsExitNode: Bool?,
        tags: [String]
    ) {
        self.id = id
        self.name = name
        self.platform = platform
        self.status = status
        self.endpoint = endpoint
        self.lastSeenAt = lastSeenAt
        self.allowsExitNode = allowsExitNode
        self.tags = tags
    }
}

struct CompanionRoachTailStatus: Codable, Hashable, Sendable {
    let enabled: Bool
    let networkName: String
    let deviceName: String
    let deviceId: String
    let status: String
    let transportMode: String?
    let secureOverlay: Bool?
    let relayHost: String?
    let advertisedUrl: String?
    let runtimeOrigin: String?
    let runtimeTunnelUrl: String?
    let joinCode: String?
    let joinCodeExpiresAt: Date?
    let pairingPayload: String?
    let pairingIssuedAt: Date?
    let lastUpdatedAt: Date?
    let notes: [String]
    let peers: [CompanionRoachTailPeer]

    enum CodingKeys: String, CodingKey {
        case enabled
        case networkName
        case deviceName
        case deviceId
        case status
        case transportMode
        case secureOverlay
        case relayHost
        case advertisedUrl
        case runtimeOrigin
        case runtimeTunnelUrl
        case joinCode
        case joinCodeExpiresAt
        case pairingPayload
        case pairingIssuedAt
        case lastUpdatedAt
        case notes
        case peers
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = (try? container.decode(Bool.self, forKey: .enabled)) ?? false
        networkName = (try? container.decode(String.self, forKey: .networkName)) ?? "RoachTail"
        deviceName = (try? container.decode(String.self, forKey: .deviceName)) ?? "RoachNet device"
        deviceId = (try? container.decode(String.self, forKey: .deviceId)) ?? UUID().uuidString
        status = (try? container.decode(String.self, forKey: .status)) ?? "local-only"
        transportMode = try? container.decodeIfPresent(String.self, forKey: .transportMode)
        secureOverlay = try? container.decodeIfPresent(Bool.self, forKey: .secureOverlay)
        relayHost = try? container.decodeIfPresent(String.self, forKey: .relayHost)
        advertisedUrl = try? container.decodeIfPresent(String.self, forKey: .advertisedUrl)
        runtimeOrigin = try? container.decodeIfPresent(String.self, forKey: .runtimeOrigin)
        runtimeTunnelUrl = try? container.decodeIfPresent(String.self, forKey: .runtimeTunnelUrl)
        joinCode = try? container.decodeIfPresent(String.self, forKey: .joinCode)
        joinCodeExpiresAt = container.decodeLossyDateIfPresent(forKey: .joinCodeExpiresAt)
        pairingPayload = try? container.decodeIfPresent(String.self, forKey: .pairingPayload)
        pairingIssuedAt = container.decodeLossyDateIfPresent(forKey: .pairingIssuedAt)
        lastUpdatedAt = container.decodeLossyDateIfPresent(forKey: .lastUpdatedAt)
        notes = (try? container.decode([String].self, forKey: .notes)) ?? []
        peers = (try? container.decode([CompanionRoachTailPeer].self, forKey: .peers)) ?? []
    }

    init(
        enabled: Bool,
        networkName: String,
        deviceName: String,
        deviceId: String,
        status: String,
        transportMode: String?,
        secureOverlay: Bool?,
        relayHost: String?,
        advertisedUrl: String?,
        runtimeOrigin: String?,
        runtimeTunnelUrl: String?,
        joinCode: String?,
        joinCodeExpiresAt: Date?,
        pairingPayload: String?,
        pairingIssuedAt: Date?,
        lastUpdatedAt: Date?,
        notes: [String],
        peers: [CompanionRoachTailPeer]
    ) {
        self.enabled = enabled
        self.networkName = networkName
        self.deviceName = deviceName
        self.deviceId = deviceId
        self.status = status
        self.transportMode = transportMode
        self.secureOverlay = secureOverlay
        self.relayHost = relayHost
        self.advertisedUrl = advertisedUrl
        self.runtimeOrigin = runtimeOrigin
        self.runtimeTunnelUrl = runtimeTunnelUrl
        self.joinCode = joinCode
        self.joinCodeExpiresAt = joinCodeExpiresAt
        self.pairingPayload = pairingPayload
        self.pairingIssuedAt = pairingIssuedAt
        self.lastUpdatedAt = lastUpdatedAt
        self.notes = notes
        self.peers = peers
    }
}

struct CompanionRoachSyncPeer: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let deviceId: String
    let status: String
    let lastSeenAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case deviceId
        case status
        case lastSeenAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        name = (try? container.decode(String.self, forKey: .name)) ?? "RoachSync peer"
        deviceId = (try? container.decode(String.self, forKey: .deviceId)) ?? UUID().uuidString
        status = (try? container.decode(String.self, forKey: .status)) ?? "linked"
        lastSeenAt = container.decodeLossyDateIfPresent(forKey: .lastSeenAt)
    }

    init(
        id: String,
        name: String,
        deviceId: String,
        status: String,
        lastSeenAt: Date?
    ) {
        self.id = id
        self.name = name
        self.deviceId = deviceId
        self.status = status
        self.lastSeenAt = lastSeenAt
    }
}

struct CompanionRoachSyncStatus: Codable, Hashable, Sendable {
    let enabled: Bool
    let provider: String
    let networkName: String
    let deviceName: String
    let deviceId: String
    let status: String
    let folderId: String
    let folderPath: String
    let guiUrl: String?
    let apiUrl: String?
    let transportMode: String?
    let secureOverlay: Bool?
    let notes: [String]
    let peers: [CompanionRoachSyncPeer]
    let lastUpdatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case enabled
        case provider
        case networkName
        case deviceName
        case deviceId
        case status
        case folderId
        case folderPath
        case guiUrl
        case apiUrl
        case transportMode
        case secureOverlay
        case notes
        case peers
        case lastUpdatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        enabled = (try? container.decode(Bool.self, forKey: .enabled)) ?? false
        provider = (try? container.decode(String.self, forKey: .provider)) ?? "Syncthing"
        networkName = (try? container.decode(String.self, forKey: .networkName)) ?? "RoachSync"
        deviceName = (try? container.decode(String.self, forKey: .deviceName)) ?? "RoachNet device"
        deviceId = (try? container.decode(String.self, forKey: .deviceId)) ?? UUID().uuidString
        status = (try? container.decode(String.self, forKey: .status)) ?? "idle"
        folderId = (try? container.decode(String.self, forKey: .folderId)) ?? "roachnet-vault"
        folderPath = (try? container.decode(String.self, forKey: .folderPath)) ?? ""
        guiUrl = try? container.decodeIfPresent(String.self, forKey: .guiUrl)
        apiUrl = try? container.decodeIfPresent(String.self, forKey: .apiUrl)
        transportMode = try? container.decodeIfPresent(String.self, forKey: .transportMode)
        secureOverlay = try? container.decodeIfPresent(Bool.self, forKey: .secureOverlay)
        notes = (try? container.decode([String].self, forKey: .notes)) ?? []
        peers = (try? container.decode([CompanionRoachSyncPeer].self, forKey: .peers)) ?? []
        lastUpdatedAt = container.decodeLossyDateIfPresent(forKey: .lastUpdatedAt)
    }

    init(
        enabled: Bool,
        provider: String,
        networkName: String,
        deviceName: String,
        deviceId: String,
        status: String,
        folderId: String,
        folderPath: String,
        guiUrl: String?,
        apiUrl: String?,
        transportMode: String?,
        secureOverlay: Bool?,
        notes: [String],
        peers: [CompanionRoachSyncPeer],
        lastUpdatedAt: Date?
    ) {
        self.enabled = enabled
        self.provider = provider
        self.networkName = networkName
        self.deviceName = deviceName
        self.deviceId = deviceId
        self.status = status
        self.folderId = folderId
        self.folderPath = folderPath
        self.guiUrl = guiUrl
        self.apiUrl = apiUrl
        self.transportMode = transportMode
        self.secureOverlay = secureOverlay
        self.notes = notes
        self.peers = peers
        self.lastUpdatedAt = lastUpdatedAt
    }
}

struct CompanionAccountStatus: Codable, Hashable, Sendable {
    let linked: Bool
    let provider: String
    let portalUrl: String
    let accountId: String?
    let email: String?
    let displayName: String?
    let status: String
    let settingsSyncEnabled: Bool
    let savedAppsSyncEnabled: Bool
    let hostedChatEnabled: Bool
    let aliasHost: String
    let bridgeUrl: String?
    let runtimeOrigin: String?
    let linkedAt: Date?
    let lastSeenAt: Date?
    let lastUpdatedAt: Date?
    let notes: [String]

    enum CodingKeys: String, CodingKey {
        case linked
        case provider
        case portalUrl
        case accountId
        case email
        case displayName
        case status
        case settingsSyncEnabled
        case savedAppsSyncEnabled
        case hostedChatEnabled
        case aliasHost
        case bridgeUrl
        case runtimeOrigin
        case linkedAt
        case lastSeenAt
        case lastUpdatedAt
        case notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        linked = (try? container.decode(Bool.self, forKey: .linked)) ?? false
        provider = (try? container.decode(String.self, forKey: .provider)) ?? "RoachNet Account"
        portalUrl = (try? container.decode(String.self, forKey: .portalUrl)) ?? "https://accounts.roachnet.org/"
        accountId = try? container.decodeIfPresent(String.self, forKey: .accountId)
        email = try? container.decodeIfPresent(String.self, forKey: .email)
        displayName = try? container.decodeIfPresent(String.self, forKey: .displayName)
        status = (try? container.decode(String.self, forKey: .status)) ?? "local-only"
        settingsSyncEnabled = (try? container.decode(Bool.self, forKey: .settingsSyncEnabled)) ?? false
        savedAppsSyncEnabled = (try? container.decode(Bool.self, forKey: .savedAppsSyncEnabled)) ?? false
        hostedChatEnabled = (try? container.decode(Bool.self, forKey: .hostedChatEnabled)) ?? false
        aliasHost = (try? container.decode(String.self, forKey: .aliasHost)) ?? "RoachNet"
        bridgeUrl = try? container.decodeIfPresent(String.self, forKey: .bridgeUrl)
        runtimeOrigin = try? container.decodeIfPresent(String.self, forKey: .runtimeOrigin)
        linkedAt = container.decodeLossyDateIfPresent(forKey: .linkedAt)
        lastSeenAt = container.decodeLossyDateIfPresent(forKey: .lastSeenAt)
        lastUpdatedAt = container.decodeLossyDateIfPresent(forKey: .lastUpdatedAt)
        notes = (try? container.decode([String].self, forKey: .notes)) ?? []
    }

    init(
        linked: Bool,
        provider: String,
        portalUrl: String,
        accountId: String?,
        email: String?,
        displayName: String?,
        status: String,
        settingsSyncEnabled: Bool,
        savedAppsSyncEnabled: Bool,
        hostedChatEnabled: Bool,
        aliasHost: String,
        bridgeUrl: String?,
        runtimeOrigin: String?,
        linkedAt: Date?,
        lastSeenAt: Date?,
        lastUpdatedAt: Date?,
        notes: [String]
    ) {
        self.linked = linked
        self.provider = provider
        self.portalUrl = portalUrl
        self.accountId = accountId
        self.email = email
        self.displayName = displayName
        self.status = status
        self.settingsSyncEnabled = settingsSyncEnabled
        self.savedAppsSyncEnabled = savedAppsSyncEnabled
        self.hostedChatEnabled = hostedChatEnabled
        self.aliasHost = aliasHost
        self.bridgeUrl = bridgeUrl
        self.runtimeOrigin = runtimeOrigin
        self.linkedAt = linkedAt
        self.lastSeenAt = lastSeenAt
        self.lastUpdatedAt = lastUpdatedAt
        self.notes = notes
    }
}

struct CompanionService: Codable, Identifiable, Hashable, Sendable {
    let serviceName: String
    let friendlyName: String?
    let status: String?
    let installed: Bool?

    var id: String { serviceName }
}

struct CompanionDownloadJob: Codable, Identifiable, Hashable, Sendable {
    let jobId: String
    let progress: Int?
    let status: String?
    let filepath: String?

    var id: String { jobId }
}

struct CompanionInstalledModel: Codable, Identifiable, Hashable, Sendable {
    let name: String
    let size: Int64?

    var id: String { name }
}

struct CompanionActionResponse: Codable, Hashable, Sendable {
    let success: Bool?
    let message: String?
}

struct CompanionRoachTailPairResponse: Codable, Hashable, Sendable {
    let success: Bool?
    let message: String?
    let token: String
    let peerId: String
    let bridgeUrl: String?
    let state: CompanionRoachTailStatus?
}

struct CompanionRoachTailPairingPayload: Codable, Hashable, Sendable {
    let schema: String
    let version: Int
    let networkName: String
    let deviceName: String
    let deviceId: String
    let joinCode: String
    let joinCodeExpiresAt: Date?
    let bridgeUrl: String?
    let runtimeOrigin: String?
    let runtimeTunnelUrl: String?
    let transportMode: String?
    let secureOverlay: Bool?

    enum CodingKeys: String, CodingKey {
        case schema
        case version
        case networkName
        case deviceName
        case deviceId
        case joinCode
        case joinCodeExpiresAt
        case bridgeUrl
        case runtimeOrigin
        case runtimeTunnelUrl
        case transportMode
        case secureOverlay
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schema = (try? container.decode(String.self, forKey: .schema)) ?? "roachnet.roachtail.v1"
        version = (try? container.decode(Int.self, forKey: .version)) ?? 1
        networkName = (try? container.decode(String.self, forKey: .networkName)) ?? "RoachTail"
        deviceName = (try? container.decode(String.self, forKey: .deviceName)) ?? "RoachNet device"
        deviceId = (try? container.decode(String.self, forKey: .deviceId)) ?? UUID().uuidString
        joinCode = (try? container.decode(String.self, forKey: .joinCode)) ?? ""
        joinCodeExpiresAt = container.decodeLossyDateIfPresent(forKey: .joinCodeExpiresAt)
        bridgeUrl = try? container.decodeIfPresent(String.self, forKey: .bridgeUrl)
        runtimeOrigin = try? container.decodeIfPresent(String.self, forKey: .runtimeOrigin)
        runtimeTunnelUrl = try? container.decodeIfPresent(String.self, forKey: .runtimeTunnelUrl)
        transportMode = try? container.decodeIfPresent(String.self, forKey: .transportMode)
        secureOverlay = try? container.decodeIfPresent(Bool.self, forKey: .secureOverlay)
    }

    init(
        schema: String,
        version: Int,
        networkName: String,
        deviceName: String,
        deviceId: String,
        joinCode: String,
        joinCodeExpiresAt: Date?,
        bridgeUrl: String?,
        runtimeOrigin: String?,
        runtimeTunnelUrl: String?,
        transportMode: String?,
        secureOverlay: Bool?
    ) {
        self.schema = schema
        self.version = version
        self.networkName = networkName
        self.deviceName = deviceName
        self.deviceId = deviceId
        self.joinCode = joinCode
        self.joinCodeExpiresAt = joinCodeExpiresAt
        self.bridgeUrl = bridgeUrl
        self.runtimeOrigin = runtimeOrigin
        self.runtimeTunnelUrl = runtimeTunnelUrl
        self.transportMode = transportMode
        self.secureOverlay = secureOverlay
    }
}

struct CompanionHardwareProfile: Codable, Hashable, Sendable {
    let platformLabel: String?
    let chipFamily: String?
    let recommendedModelClass: String?
    let notes: [String]?
    let warnings: [String]?
}

struct CompanionMemoryInfo: Codable, Hashable, Sendable {
    let total: UInt64
    let available: UInt64?
    let swapused: Double?
}

struct CompanionOSInfo: Codable, Hashable, Sendable {
    let hostname: String?
    let arch: String?
    let distro: String?
}

struct CompanionSystemInfo: Codable, Hashable, Sendable {
    let mem: CompanionMemoryInfo?
    let os: CompanionOSInfo?
    let hardwareProfile: CompanionHardwareProfile?
}

struct CompanionRuntimeSummary: Codable, Hashable, Sendable {
    let systemInfo: CompanionSystemInfo?
    let providers: CompanionProviderEnvelope
    let roachClaw: CompanionRoachClawStatus
    let account: CompanionAccountStatus?
    let roachTail: CompanionRoachTailStatus?
    let roachSync: CompanionRoachSyncStatus?
    let services: [CompanionService]
    let downloads: [CompanionDownloadJob]
    let installedModels: [CompanionInstalledModel]
    let issues: [CompanionIssue]
}

struct CompanionSiteArchive: Codable, Identifiable, Hashable, Sendable {
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

    init(
        slug: String,
        title: String?,
        sourceUrl: String?,
        entryUrl: String?,
        createdAt: Date?,
        status: String?,
        note: String?
    ) {
        self.slug = slug
        self.title = title
        self.sourceUrl = sourceUrl
        self.entryUrl = entryUrl
        self.createdAt = createdAt
        self.status = status
        self.note = note
    }
}

struct RoachBrainMemorySummary: Codable, Identifiable, Hashable, Sendable {
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

    init(
        id: String,
        title: String,
        summary: String,
        source: String,
        tags: [String],
        pinned: Bool,
        lastAccessedAt: Date?
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.source = source
        self.tags = tags
        self.pinned = pinned
        self.lastAccessedAt = lastAccessedAt
    }
}

struct CompanionVaultShelfItem: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let detail: String
    let kind: String
    let status: String
    let actionLabel: String?
    let routePath: String?
    let installed: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case detail
        case kind
        case status
        case actionLabel
        case routePath
        case installed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        title = (try? container.decode(String.self, forKey: .title)) ?? "Vault shelf"
        detail = (try? container.decode(String.self, forKey: .detail)) ?? ""
        kind = (try? container.decode(String.self, forKey: .kind)) ?? "shelf"
        status = (try? container.decode(String.self, forKey: .status)) ?? "Ready"
        actionLabel = try? container.decodeIfPresent(String.self, forKey: .actionLabel)
        routePath = try? container.decodeIfPresent(String.self, forKey: .routePath)
        installed = (try? container.decode(Bool.self, forKey: .installed)) ?? false
    }

    init(
        id: String,
        title: String,
        detail: String,
        kind: String,
        status: String,
        actionLabel: String? = nil,
        routePath: String? = nil,
        installed: Bool
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.kind = kind
        self.status = status
        self.actionLabel = actionLabel
        self.routePath = routePath
        self.installed = installed
    }
}

struct CompanionVaultSummary: Codable, Hashable, Sendable {
    let knowledgeFiles: [String]
    let siteArchives: [CompanionSiteArchive]
    let roachBrain: [RoachBrainMemorySummary]
    let atlasShelves: [CompanionVaultShelfItem]
    let studyShelves: [CompanionVaultShelfItem]
    let referenceShelves: [CompanionVaultShelfItem]
    let issues: [CompanionIssue]

    enum CodingKeys: String, CodingKey {
        case knowledgeFiles
        case siteArchives
        case roachBrain
        case atlasShelves
        case studyShelves
        case referenceShelves
        case issues
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        knowledgeFiles = (try? container.decode([String].self, forKey: .knowledgeFiles)) ?? []
        siteArchives = (try? container.decode([CompanionSiteArchive].self, forKey: .siteArchives)) ?? []
        roachBrain = (try? container.decode([RoachBrainMemorySummary].self, forKey: .roachBrain)) ?? []
        atlasShelves = (try? container.decode([CompanionVaultShelfItem].self, forKey: .atlasShelves)) ?? []
        studyShelves = (try? container.decode([CompanionVaultShelfItem].self, forKey: .studyShelves)) ?? []
        referenceShelves = (try? container.decode([CompanionVaultShelfItem].self, forKey: .referenceShelves)) ?? []
        issues = (try? container.decode([CompanionIssue].self, forKey: .issues)) ?? []
    }

    init(
        knowledgeFiles: [String],
        siteArchives: [CompanionSiteArchive],
        roachBrain: [RoachBrainMemorySummary],
        atlasShelves: [CompanionVaultShelfItem] = [],
        studyShelves: [CompanionVaultShelfItem] = [],
        referenceShelves: [CompanionVaultShelfItem] = [],
        issues: [CompanionIssue]
    ) {
        self.knowledgeFiles = knowledgeFiles
        self.siteArchives = siteArchives
        self.roachBrain = roachBrain
        self.atlasShelves = atlasShelves
        self.studyShelves = studyShelves
        self.referenceShelves = referenceShelves
        self.issues = issues
    }
}

struct CompanionBootstrapResponse: Codable, Sendable {
    let appName: String
    let machineName: String
    let appsCatalogUrl: String
    let runtime: CompanionRuntimeSummary
    let vault: CompanionVaultSummary
    let sessions: [CompanionChatSessionSummary]
}

struct StoreCatalogResponse: Codable, Sendable {
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

struct StoreInstallIntent: Codable, Hashable, Sendable {
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

    init(values: [String: String]) {
        self.values = values
    }
}

struct StoreAppItem: Codable, Identifiable, Hashable, Sendable {
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

struct CompanionInstallResponse: Codable, Sendable {
    let ok: Bool
    let action: String
}
