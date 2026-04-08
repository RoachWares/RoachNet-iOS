import Foundation

enum RoachNetAPIError: LocalizedError {
    case invalidBaseURL
    case notConfigured
    case requestFailed(String)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "The companion URL is not valid."
        case .notConfigured:
            return "Add the Mac companion URL and token first."
        case .requestFailed(let message):
            return message
        case .decodingFailed(let message):
            return message
        }
    }
}

struct CompanionConnectionSettings: Codable, Hashable, Sendable {
    var baseURL: String
    var token: String
    var pairCode: String

    static let storageKey = "RoachNetCompanionConnection"

    private enum CodingKeys: String, CodingKey {
        case baseURL
        case token
        case pairCode
    }

    static func load() -> CompanionConnectionSettings {
        if
            let rawString = UserDefaults.standard.string(forKey: storageKey),
            let rawData = rawString.data(using: .utf8),
            let decoded = try? JSONDecoder().decode(CompanionConnectionSettings.self, from: rawData)
        {
            return decoded
        }

        if
            let raw = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode(CompanionConnectionSettings.self, from: raw)
        {
            return decoded
        }

        return CompanionConnectionSettings(
            baseURL: defaultBaseURL,
            token: "",
            pairCode: ""
        )
    }

    private static var defaultBaseURL: String {
        "http://RoachNet:38111"
    }

    func save() {
        guard let encoded = try? JSONEncoder().encode(self) else {
            return
        }

        UserDefaults.standard.set(encoded, forKey: Self.storageKey)
    }

    init(baseURL: String, token: String, pairCode: String = "") {
        self.baseURL = baseURL
        self.token = token
        self.pairCode = pairCode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? Self.defaultBaseURL
        token = try container.decodeIfPresent(String.self, forKey: .token) ?? ""
        pairCode = try container.decodeIfPresent(String.self, forKey: .pairCode) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(baseURL, forKey: .baseURL)
        try container.encode(token, forKey: .token)
        try container.encode(pairCode, forKey: .pairCode)
    }

    var isConfigured: Bool {
        resolvedBaseURL != nil && !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var usesRoachTailPeerToken: Bool {
        token.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("rtp_")
    }

    var resolvedBaseURL: URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed.hasSuffix("/") ? trimmed : "\(trimmed)/")
    }
}

struct RoachNetAPIClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.requestCachePolicy = .returnCacheDataElseLoad
            configuration.timeoutIntervalForRequest = 18
            configuration.timeoutIntervalForResource = 30
            configuration.waitsForConnectivity = false
            configuration.urlCache = URLCache(
                memoryCapacity: 8 * 1024 * 1024,
                diskCapacity: 32 * 1024 * 1024
            )
            self.session = URLSession(configuration: configuration)
        }
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func bootstrap(using connection: CompanionConnectionSettings) async throws -> CompanionBootstrapResponse {
        try await request("/api/companion/bootstrap", using: connection)
    }

    func runtime(using connection: CompanionConnectionSettings) async throws -> CompanionRuntimeSummary {
        try await request("/api/companion/runtime", using: connection)
    }

    func vault(using connection: CompanionConnectionSettings) async throws -> CompanionVaultSummary {
        try await request("/api/companion/vault", using: connection)
    }

    func roachTail(using connection: CompanionConnectionSettings) async throws -> CompanionRoachTailStatus {
        try await request("/api/companion/roachtail", using: connection)
    }

    func pairRoachTail(
        joinCode: String,
        peerID: String,
        peerName: String,
        platform: String,
        appVersion: String? = nil,
        tags: [String] = [],
        using connection: CompanionConnectionSettings
    ) async throws -> CompanionRoachTailPairResponse {
        guard let baseURL = connection.resolvedBaseURL else {
            throw RoachNetAPIError.invalidBaseURL
        }

        let url = URL(string: "api/companion/roachtail/pair", relativeTo: baseURL) ?? baseURL.appendingPathComponent("api/companion/roachtail/pair")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "joinCode": joinCode,
            "peerId": peerID,
            "peerName": peerName,
            "platform": platform,
            "appVersion": appVersion ?? "",
            "tags": tags,
        ])

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RoachNetAPIError.requestFailed("The RoachTail pair lane did not return an HTTP response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let envelope = try? decoder.decode(APIErrorEnvelope.self, from: data) {
                throw RoachNetAPIError.requestFailed(envelope.error)
            }

            throw RoachNetAPIError.requestFailed("The RoachTail pair lane returned \(httpResponse.statusCode).")
        }

        return try decode(CompanionRoachTailPairResponse.self, from: data)
    }

    func createSession(
        title: String = "New Chat",
        model: String? = nil,
        using connection: CompanionConnectionSettings
    ) async throws -> CompanionChatSessionSummary {
        var body: [String: Any] = ["title": title]
        if let model, !model.isEmpty {
            body["model"] = model
        }
        return try await request(
            "/api/companion/chat/sessions",
            method: "POST",
            body: body,
            using: connection
        )
    }

    func session(
        id: String,
        using connection: CompanionConnectionSettings
    ) async throws -> CompanionChatSessionDetail {
        try await request("/api/companion/chat/sessions/\(id)", using: connection)
    }

    func sendMessage(
        sessionID: String?,
        content: String,
        history: [CompanionChatMessage] = [],
        model: String? = nil,
        using connection: CompanionConnectionSettings
    ) async throws -> CompanionSendMessageResponse {
        var body: [String: Any] = ["content": content]
        if let sessionID, !sessionID.isEmpty {
            body["sessionId"] = sessionID
        }
        if let model, !model.isEmpty {
            body["model"] = model
        }
        if !history.isEmpty {
            body["messages"] = history.map { message in
                [
                    "role": message.role,
                    "content": message.content,
                ]
            }
        }

        return try await request(
            "/api/companion/chat/send",
            method: "POST",
            body: body,
            using: connection
        )
    }

    func install(
        intent: StoreInstallIntent,
        using connection: CompanionConnectionSettings
    ) async throws -> CompanionInstallResponse {
        try await request(
            "/api/companion/install",
            method: "POST",
            body: intent.values,
            using: connection
        )
    }

    func affectService(
        serviceName: String,
        action: String,
        using connection: CompanionConnectionSettings
    ) async throws -> CompanionActionResponse {
        try await request(
            "/api/companion/services/affect",
            method: "POST",
            body: [
                "serviceName": serviceName,
                "action": action,
            ],
            using: connection
        )
    }

    func affectRoachTail(
        action: String,
        peerID: String? = nil,
        peerName: String? = nil,
        platform: String? = nil,
        endpoint: String? = nil,
        relayHost: String? = nil,
        tags: [String] = [],
        using connection: CompanionConnectionSettings
    ) async throws -> CompanionActionResponse {
        var body: [String: Any] = [
            "action": action,
        ]

        if let peerID, !peerID.isEmpty {
            body["peerId"] = peerID
        }
        if let peerName, !peerName.isEmpty {
            body["peerName"] = peerName
        }
        if let platform, !platform.isEmpty {
            body["platform"] = platform
        }
        if let endpoint, !endpoint.isEmpty {
            body["endpoint"] = endpoint
        }
        if let relayHost, !relayHost.isEmpty {
            body["relayHost"] = relayHost
        }
        if !tags.isEmpty {
            body["tags"] = tags
        }

        return try await request(
            "/api/companion/roachtail/affect",
            method: "POST",
            body: body,
            using: connection
        )
    }

    func affectRoachSync(
        action: String,
        folderPath: String? = nil,
        using connection: CompanionConnectionSettings
    ) async throws -> CompanionActionResponse {
        var body: [String: Any] = [
            "action": action,
        ]

        if let folderPath, !folderPath.isEmpty {
            body["folderPath"] = folderPath
        }

        return try await request(
            "/api/companion/roachsync/affect",
            method: "POST",
            body: body,
            using: connection
        )
    }

    func fetchCatalog(from catalogURL: String) async throws -> StoreCatalogResponse {
        guard let url = URL(string: catalogURL) else {
            throw RoachNetAPIError.invalidBaseURL
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RoachNetAPIError.requestFailed("The Apps catalog did not return an HTTP response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw RoachNetAPIError.requestFailed("The Apps catalog returned \(httpResponse.statusCode).")
        }

        return try decode(StoreCatalogResponse.self, from: data)
    }

    private func request<T: Decodable>(
        _ path: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        using connection: CompanionConnectionSettings
    ) async throws -> T {
        guard let baseURL = connection.resolvedBaseURL else {
            throw RoachNetAPIError.notConfigured
        }

        let token = connection.token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            throw RoachNetAPIError.notConfigured
        }

        let url = URL(string: path.trimmingCharacters(in: CharacterSet(charactersIn: "/")), relativeTo: baseURL)
            ?? baseURL.appendingPathComponent(path)

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RoachNetAPIError.requestFailed("The companion runtime did not return an HTTP response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let envelope = try? decoder.decode(APIErrorEnvelope.self, from: data) {
                throw RoachNetAPIError.requestFailed(envelope.error)
            }

            throw RoachNetAPIError.requestFailed("The companion runtime returned \(httpResponse.statusCode).")
        }

        return try decode(T.self, from: data)
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw RoachNetAPIError.decodingFailed(error.localizedDescription)
        }
    }
}
