import Foundation
import Security

enum RoachNetAPIError: LocalizedError {
    case invalidBaseURL
    case notConfigured
    case requestFailed(String)
    case http(status: Int, message: String)
    case unreachable(String)
    case decodingFailed(String)

    var statusCode: Int? {
        if case .http(let status, _) = self { return status }
        return nil
    }

    var errorDescription: String? {
        switch self {
        case .invalidBaseURL:
            return "The companion URL must be HTTPS or a trusted local RoachNet lane."
        case .notConfigured:
            return "Add the Mac companion URL and token first."
        case .requestFailed(let message):
            return message
        case .http(_, let message):
            return message
        case .unreachable(let host):
            return "Can't reach your Mac at \(host). Check RoachNet is open on it and this phone is on the same network or RoachTail."
        case .decodingFailed(let message):
            return message
        }
    }
}

private enum CompanionEndpointPolicy {
    static func normalizedBaseURL(from rawValue: String) -> URL? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, var components = URLComponents(string: trimmed) else {
            return nil
        }

        guard let scheme = components.scheme?.lowercased(), let host = components.host?.lowercased(), !host.isEmpty else {
            return nil
        }

        switch scheme {
        case "https":
            break
        case "http":
            guard isTrustedPlaintextHost(host) else { return nil }
        default:
            return nil
        }

        components.scheme = scheme
        components.fragment = nil

        if components.path.isEmpty {
            components.path = "/"
        }

        return components.url
    }

    static func securityLabel(for connection: CompanionConnectionSettings) -> String {
        guard let url = connection.resolvedBaseURL else {
            return "Needs trusted lane"
        }

        if connection.usesRoachTailPeerToken {
            return "RoachTail peer"
        }

        if url.scheme?.lowercased() == "https" {
            return "Secure relay"
        }

        return "Local bridge"
    }

    static func securityDetail(for connection: CompanionConnectionSettings) -> String {
        guard let url = connection.resolvedBaseURL else {
            return "Use HTTPS or a trusted local RoachNet bridge URL."
        }

        if connection.usesRoachTailPeerToken {
            return "This phone is paired over a peer-scoped RoachTail token instead of a shared desktop token."
        }

        if url.scheme?.lowercased() == "https" {
            return "Traffic is pinned to an HTTPS relay lane."
        }

        return "Traffic stays on a trusted local companion lane."
    }

    private static func isTrustedPlaintextHost(_ host: String) -> Bool {
        if ["roachnet", "localhost", "127.0.0.1", "::1"].contains(host) {
            return true
        }

        if host.hasSuffix(".local") || host.hasSuffix(".home.arpa") || host.hasSuffix(".internal") || host.hasSuffix(".roachtail") || host.hasSuffix(".roachtail.local") {
            return true
        }

        if isPrivateIPv4(host) || isPrivateIPv6(host) {
            return true
        }

        return false
    }

    private static func isPrivateIPv4(_ host: String) -> Bool {
        let octets = host.split(separator: ".").compactMap { Int($0) }
        guard octets.count == 4 else { return false }

        switch (octets[0], octets[1]) {
        case (10, _), (127, _):
            return true
        case (169, 254):
            return true
        case (192, 168):
            return true
        case (172, 16...31):
            return true
        default:
            return false
        }
    }

    private static func isPrivateIPv6(_ host: String) -> Bool {
        let lowered = host.lowercased()
        return lowered == "::1" || lowered.hasPrefix("fe80:") || lowered.hasPrefix("fd") || lowered.hasPrefix("fc")
    }
}

private enum CompanionSecretStore {
    private static let service = "org.roachnet.ios"
    private static let account = "companion-token"

    static func loadToken() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data, let token = String(data: data, encoding: .utf8) else {
            return ""
        }

        return token
    }

    static func saveToken(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            deleteToken()
            return
        }

        let encoded = Data(trimmed.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: encoded,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        var create = query
        attributes.forEach { create[$0.key] = $0.value }
        SecItemAdd(create as CFDictionary, nil)
    }

    static func deleteToken() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

struct CompanionConnectionSettings: Codable, Hashable, Sendable {
    var baseURL: String
    var token: String
    var pairCode: String

    static let storageKey = "RoachNetCompanionConnection"
    static let recommendedBaseURL = "http://RoachNet:38111"

    /// `scheme://host:port` for a lane, lowercased, or the trimmed raw text when
    /// it does not parse. Two links to the same Mac compare equal; a link to
    /// anywhere else does not.
    static func originLabel(for rawValue: String) -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed), let scheme = components.scheme?.lowercased(),
              let host = components.host?.lowercased(), !host.isEmpty
        else { return trimmed.lowercased() }
        let port = components.port.map { ":\($0)" } ?? ""
        return "\(scheme)://\(host)\(port)"
    }

    private enum CodingKeys: String, CodingKey {
        case baseURL
        case token
        case pairCode
    }

    static func load() -> CompanionConnectionSettings {
        let storedToken = CompanionSecretStore.loadToken()
        if
            let rawString = UserDefaults.standard.string(forKey: storageKey),
            let rawData = rawString.data(using: .utf8),
            let decoded = try? JSONDecoder().decode(CompanionConnectionSettings.self, from: rawData)
        {
            let token = storedToken.isEmpty ? decoded.token : storedToken
            let migrated = CompanionConnectionSettings(baseURL: decoded.baseURL, token: token, pairCode: decoded.pairCode)
            if storedToken.isEmpty, !decoded.token.isEmpty {
                migrated.save()
            }
            return migrated
        }

        if
            let raw = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode(CompanionConnectionSettings.self, from: raw)
        {
            let token = storedToken.isEmpty ? decoded.token : storedToken
            let migrated = CompanionConnectionSettings(baseURL: decoded.baseURL, token: token, pairCode: decoded.pairCode)
            if storedToken.isEmpty, !decoded.token.isEmpty {
                migrated.save()
            }
            return migrated
        }

        return CompanionConnectionSettings(
            baseURL: recommendedBaseURL,
            token: storedToken,
            pairCode: ""
        )
    }

    func save() {
        CompanionSecretStore.saveToken(token)
        var sanitized = self
        sanitized.token = ""
        guard let encoded = try? JSONEncoder().encode(self) else {
            return
        }

        if let sanitizedEncoded = try? JSONEncoder().encode(sanitized) {
            UserDefaults.standard.set(sanitizedEncoded, forKey: Self.storageKey)
        } else {
            UserDefaults.standard.set(encoded, forKey: Self.storageKey)
        }
    }

    init(baseURL: String, token: String, pairCode: String = "") {
        self.baseURL = baseURL
        self.token = token
        self.pairCode = pairCode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? Self.recommendedBaseURL
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
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasPrefix("rtp_") || trimmed.hasPrefix("rtpeer_")
    }

    var resolvedBaseURL: URL? {
        CompanionEndpointPolicy.normalizedBaseURL(from: baseURL)
    }

    var securityLabel: String {
        CompanionEndpointPolicy.securityLabel(for: self)
    }

    var securityDetail: String {
        CompanionEndpointPolicy.securityDetail(for: self)
    }
}

struct RoachNetAPIClient {
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            configuration.timeoutIntervalForRequest = 18
            configuration.timeoutIntervalForResource = 30
            configuration.waitsForConnectivity = false
            configuration.urlCache = nil
            configuration.httpCookieStorage = nil
            configuration.httpShouldSetCookies = false
            configuration.httpCookieAcceptPolicy = .never
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

    func account(using connection: CompanionConnectionSettings) async throws -> CompanionAccountStatus {
        try await request("/api/companion/account", using: connection)
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

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where Self.isUnreachable(error) {
            throw RoachNetAPIError.unreachable(baseURL.host ?? baseURL.absoluteString)
        }
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
        images: [String] = [],
        visionSummary: String? = nil,
        using connection: CompanionConnectionSettings
    ) async throws -> CompanionSendMessageResponse {
        var body: [String: Any] = ["content": content]
        if let sessionID, !sessionID.isEmpty {
            body["sessionId"] = sessionID
        }
        if let model, !model.isEmpty {
            body["model"] = model
        }
        if !images.isEmpty {
            body["images"] = images
        }
        if let visionSummary, !visionSummary.isEmpty {
            body["visionSummary"] = visionSummary
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

    func affectAccount(
        action: String,
        accountId: String? = nil,
        email: String? = nil,
        displayName: String? = nil,
        portalUrl: String? = nil,
        settingsSyncEnabled: Bool? = nil,
        savedAppsSyncEnabled: Bool? = nil,
        hostedChatEnabled: Bool? = nil,
        using connection: CompanionConnectionSettings
    ) async throws -> CompanionActionResponse {
        var body: [String: Any] = [
            "action": action,
        ]

        if let accountId, !accountId.isEmpty {
            body["accountId"] = accountId
        }
        if let email, !email.isEmpty {
            body["email"] = email
        }
        if let displayName, !displayName.isEmpty {
            body["displayName"] = displayName
        }
        if let portalUrl, !portalUrl.isEmpty {
            body["portalUrl"] = portalUrl
        }
        if let settingsSyncEnabled {
            body["settingsSyncEnabled"] = settingsSyncEnabled
        }
        if let savedAppsSyncEnabled {
            body["savedAppsSyncEnabled"] = savedAppsSyncEnabled
        }
        if let hostedChatEnabled {
            body["hostedChatEnabled"] = hostedChatEnabled
        }

        return try await request(
            "/api/companion/account/affect",
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

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where Self.isUnreachable(error) {
            throw RoachNetAPIError.unreachable(baseURL.host ?? baseURL.absoluteString)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw RoachNetAPIError.requestFailed("The companion runtime did not return an HTTP response.")
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            if let envelope = try? decoder.decode(APIErrorEnvelope.self, from: data) {
                throw RoachNetAPIError.http(status: httpResponse.statusCode, message: envelope.error)
            }

            throw RoachNetAPIError.http(status: httpResponse.statusCode, message: "The companion runtime returned \(httpResponse.statusCode).")
        }

        return try decode(T.self, from: data)
    }

    static func isUnreachable(_ error: URLError) -> Bool {
        [.cannotConnectToHost, .cannotFindHost, .timedOut, .networkConnectionLost, .notConnectedToInternet, .dnsLookupFailed]
            .contains(error.code)
    }

    // MARK: RoachClaw Org (desktop 1.1+)

    func orgMe(using connection: CompanionConnectionSettings) async throws -> OrgMe {
        try await request("/api/org/me", using: connection)
    }

    func orgDashboard(companyID: String, using connection: CompanionConnectionSettings) async throws -> OrgDashboard {
        try await request("/api/org/companies/\(Self.pathComponent(companyID))/dashboard", using: connection)
    }

    func orgApprovals(companyID: String, using connection: CompanionConnectionSettings) async throws -> [OrgApproval] {
        let list: OrgApprovalList = try await request("/api/org/companies/\(Self.pathComponent(companyID))/approvals", using: connection)
        return list.approvals
    }

    func orgAgents(companyID: String, using connection: CompanionConnectionSettings) async throws -> [OrgAgent] {
        let list: OrgAgentList = try await request("/api/org/companies/\(Self.pathComponent(companyID))/agents", using: connection)
        return list.agents
    }

    /// `decision` is approve, reject or request-revision.
    func decideOrgApproval(companyID: String, approvalID: String, decision: String, note: String?, using connection: CompanionConnectionSettings) async throws {
        var body: [String: Any] = [:]
        if let note, !note.isEmpty { body["note"] = note }
        let _: OrgJSONValue = try await request(
            "/api/org/companies/\(Self.pathComponent(companyID))/approvals/\(Self.pathComponent(approvalID))/\(decision)",
            method: "POST",
            body: body,
            using: connection
        )
    }

    /// `action` is pause or resume.
    func setOrgAgentStatus(companyID: String, agentID: String, action: String, using connection: CompanionConnectionSettings) async throws {
        let _: OrgJSONValue = try await request(
            "/api/org/companies/\(Self.pathComponent(companyID))/agents/\(Self.pathComponent(agentID))/\(action)",
            method: "POST",
            body: [:],
            using: connection
        )
    }

    func acceptOrgInvite(token: String, userName: String, email: String?, using connection: CompanionConnectionSettings) async throws -> OrgJoinResult {
        var body: [String: Any] = ["token": token, "requestType": "human", "userName": userName]
        if let email, !email.isEmpty { body["email"] = email }
        return try await request("/api/org/invites/accept", method: "POST", body: body, using: connection)
    }

    static func pathComponent(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))) ?? value
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw RoachNetAPIError.decodingFailed(error.localizedDescription)
        }
    }
}
