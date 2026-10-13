import Foundation

enum OrgJSONValue: Codable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: OrgJSONValue])
    case array([OrgJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: OrgJSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([OrgJSONValue].self) {
            self = .array(value)
        } else {
            self = .null
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }

    var displayText: String? {
        switch self {
        case .string(let value): return value.isEmpty ? nil : value
        case .number(let value): return value.rounded() == value ? String(Int(value)) : String(value)
        case .bool(let value): return value ? "Yes" : "No"
        default: return nil
        }
    }
}

struct OrgMembershipSummary: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let board: Bool
    let role: String?

    enum CodingKeys: String, CodingKey { case id, name, board, role }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? "Company"
        board = (try? c.decode(Bool.self, forKey: .board)) ?? false
        role = try? c.decodeIfPresent(String.self, forKey: .role)
    }
}

struct OrgMe: Codable, Hashable, Sendable {
    struct User: Codable, Hashable, Sendable {
        let id: String?
        let name: String?
        let email: String?
    }

    let kind: String?
    let userId: String?
    let source: String?
    let user: User?
    let companies: [OrgMembershipSummary]

    enum CodingKeys: String, CodingKey { case kind, userId, source, user, companies }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try? c.decodeIfPresent(String.self, forKey: .kind)
        userId = try? c.decodeIfPresent(String.self, forKey: .userId)
        source = try? c.decodeIfPresent(String.self, forKey: .source)
        user = try? c.decodeIfPresent(User.self, forKey: .user)
        companies = (try? c.decode([OrgMembershipSummary].self, forKey: .companies)) ?? []
    }

    var isOwner: Bool { kind == "owner" }
    var displayName: String { user?.name ?? (isOwner ? "Owner" : "Member") }
}

struct OrgApprovalComment: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let authorType: String?
    let body: String
    let createdAt: String?
}

struct OrgApproval: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let companyId: String?
    let type: String
    let status: String
    let payload: [String: OrgJSONValue]
    let requestedByAgentId: String?
    let requestedByUserId: String?
    let decisionNote: String?
    let decidedAt: String?
    let comments: [OrgApprovalComment]
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case id, companyId, type, status, payload, requestedByAgentId, requestedByUserId, decisionNote, decidedAt,
            comments, createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        companyId = try? c.decodeIfPresent(String.self, forKey: .companyId)
        type = (try? c.decode(String.self, forKey: .type)) ?? "request_board_approval"
        status = (try? c.decode(String.self, forKey: .status)) ?? "pending"
        payload = (try? c.decode([String: OrgJSONValue].self, forKey: .payload)) ?? [:]
        requestedByAgentId = try? c.decodeIfPresent(String.self, forKey: .requestedByAgentId)
        requestedByUserId = try? c.decodeIfPresent(String.self, forKey: .requestedByUserId)
        decisionNote = try? c.decodeIfPresent(String.self, forKey: .decisionNote)
        decidedAt = try? c.decodeIfPresent(String.self, forKey: .decidedAt)
        comments = (try? c.decode([OrgApprovalComment].self, forKey: .comments)) ?? []
        createdAt = try? c.decodeIfPresent(String.self, forKey: .createdAt)
    }

    var isOpen: Bool { status == "pending" || status == "revision_requested" }

    var typeTitle: String {
        switch type {
        case "hire_agent": return "Hire an agent"
        case "approve_ceo_strategy": return "CEO strategy"
        case "budget_override_required": return "Budget override"
        default: return "Board approval"
        }
    }

    var headline: String {
        for key in ["title", "summary", "name", "agentName", "strategy", "reason"] {
            if let text = payload[key]?.displayText { return text }
        }
        return typeTitle
    }

    var detailLines: [(String, String)] {
        let skip: Set<String> = ["title", "summary"]
        return payload.keys.sorted().compactMap { key in
            guard !skip.contains(key), let value = payload[key]?.displayText else { return nil }
            let label = key.replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "([a-z])([A-Z])", with: "$1 $2", options: .regularExpression)
                .capitalized
            return (label, value)
        }
    }
}

struct OrgApprovalList: Codable, Sendable {
    let approvals: [OrgApproval]
}

struct OrgAgent: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let role: String?
    let title: String?
    let status: String
    let pauseReason: String?
    let errorReason: String?

    enum CodingKeys: String, CodingKey { case id, name, role, title, status, pauseReason, errorReason }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? "Agent"
        role = try? c.decodeIfPresent(String.self, forKey: .role)
        title = try? c.decodeIfPresent(String.self, forKey: .title)
        status = (try? c.decode(String.self, forKey: .status)) ?? "idle"
        pauseReason = try? c.decodeIfPresent(String.self, forKey: .pauseReason)
        errorReason = try? c.decodeIfPresent(String.self, forKey: .errorReason)
    }

    var subtitle: String { title ?? role?.uppercased() ?? "Agent" }
}

struct OrgAgentList: Codable, Sendable {
    let agents: [OrgAgent]
}

struct OrgCompanySummary: Codable, Hashable, Sendable {
    let id: String
    let name: String
    let description: String?
    let status: String?

    enum CodingKeys: String, CodingKey { case id, name, description, status }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? "Company"
        description = try? c.decodeIfPresent(String.self, forKey: .description)
        status = try? c.decodeIfPresent(String.self, forKey: .status)
    }
}

struct OrgActivityItem: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let actorType: String?
    let action: String
    let entityType: String?
    let createdAt: String?

    var title: String {
        action.replacingOccurrences(of: ".", with: " ").replacingOccurrences(of: "_", with: " ").capitalized
    }
}

struct OrgDashboard: Codable, Sendable {
    let company: OrgCompanySummary
    let issuesByStatus: [String: Int]
    let agentsByStatus: [String: Int]
    let pendingApprovals: Int
    let openIncidents: Int
    let runningRuns: Int
    let monthSpendCents: Int
    let companyBudgetCents: Int
    let recentActivity: [OrgActivityItem]

    enum CodingKeys: String, CodingKey {
        case company, issuesByStatus, agentsByStatus, pendingApprovals, openIncidents, runningRuns, monthSpendCents,
            companyBudgetCents, recentActivity
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        company = try c.decode(OrgCompanySummary.self, forKey: .company)
        issuesByStatus = (try? c.decode([String: Int].self, forKey: .issuesByStatus)) ?? [:]
        agentsByStatus = (try? c.decode([String: Int].self, forKey: .agentsByStatus)) ?? [:]
        pendingApprovals = (try? c.decode(Int.self, forKey: .pendingApprovals)) ?? 0
        openIncidents = (try? c.decode(Int.self, forKey: .openIncidents)) ?? 0
        runningRuns = (try? c.decode(Int.self, forKey: .runningRuns)) ?? 0
        monthSpendCents = (try? c.decode(Int.self, forKey: .monthSpendCents)) ?? 0
        companyBudgetCents = (try? c.decode(Int.self, forKey: .companyBudgetCents)) ?? 0
        recentActivity = (try? c.decode([OrgActivityItem].self, forKey: .recentActivity)) ?? []
    }

    var openIssues: Int {
        issuesByStatus.filter { !["done", "cancelled"].contains($0.key) }.values.reduce(0, +)
    }

    var activeAgents: Int {
        agentsByStatus.filter { !["terminated", "paused"].contains($0.key) }.values.reduce(0, +)
    }
}

struct OrgJoinResult: Codable, Sendable {
    let companyName: String?
}

enum OrgAvailability: Equatable, Sendable {
    case unknown
    case unsupported
    case needsInvite
    case pendingApproval(String)
    case ready
}
