import SwiftUI

struct OrgView: View {
    @Bindable var model: CompanionAppModel
    @Environment(\.dismiss) private var dismiss
    @State private var notes: [String: String] = [:]
    @State private var joinName = ""
    @State private var joinEmail = ""

    var body: some View {
        ZStack {
            RoachBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    content
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .refreshable { await model.refreshOrg() }
        }
        .navigationTitle("Org")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
                    .accessibilityIdentifier("org.done")
            }
        }
        .task { await model.refreshOrg() }
        .accessibilityIdentifier("screen.org")
    }

    @ViewBuilder
    private var content: some View {
        switch model.orgAvailability {
        case .unsupported:
            EmptyStateView(
                title: "Org needs RoachNet 1.1.",
                detail:
                    "Your Mac runs an older RoachNet. Update it to run an agent company and approve its work from here.",
                actionTitle: nil,
                action: nil
            )
        case .needsInvite:
            joinForm
        case .pendingApproval(let company):
            EmptyStateView(
                title: "Waiting on \(company).",
                detail: "The owner approves new members on the Mac. Pull down to check again.",
                actionTitle: "Check again",
                action: { Task { await model.refreshOrg() } }
            )
        default:
            if let dashboard = model.orgDashboard {
                companyHeader(dashboard)
                approvalsSection
                agentsSection
                activitySection(dashboard)
            } else if model.isLoadingOrg {
                ProgressView("Waking the bunker…")
                    .tint(RoachTheme.secondary)
                    .frame(maxWidth: .infinity, minHeight: 240)
            } else {
                EmptyStateView(
                    title: "No company yet.",
                    detail: "Create one in RoachClaw Org on your Mac. It shows up here once it exists.",
                    actionTitle: nil,
                    action: nil
                )
            }
        }
    }

    private func companyHeader(_ dashboard: OrgDashboard) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                RoachSectionHeader(
                    eyebrow: "RoachClaw Org", title: dashboard.company.name, detail: dashboard.company.description)
                Spacer(minLength: 0)
                if let companies = model.orgMe?.companies, companies.count > 1 {
                    Menu {
                        ForEach(companies) { company in
                            Button(company.name) { Task { await model.selectOrgCompany(company.id) } }
                        }
                    } label: {
                        Image(systemName: "chevron.up.chevron.down")
                            .frame(width: 44, height: 44)
                    }
                    .tint(RoachTheme.text)
                    .accessibilityLabel("Switch company")
                }
            }
            RoachMetricRow {
                RoachMetricTile(
                    label: "Approvals", value: "\(model.pendingOrgApprovals.count)", accent: RoachTheme.primary)
                RoachMetricTile(label: "Issues", value: "\(dashboard.openIssues)", accent: RoachTheme.cyan)
                RoachMetricTile(label: "Running", value: "\(dashboard.runningRuns)", accent: RoachTheme.secondary)
            }
        }
    }

    private var approvalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoachOverline(text: "Waiting on you", accent: RoachTheme.primary)
            if model.pendingOrgApprovals.isEmpty {
                RoachPanel {
                    Text("Nothing waiting. The agents are behaving.")
                        .font(RoachType.body)
                        .foregroundStyle(RoachTheme.subduedText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ForEach(model.pendingOrgApprovals) { approval in
                    approvalCard(approval)
                }
            }
        }
    }

    private func approvalCard(_ approval: OrgApproval) -> some View {
        let acting = model.orgActingIDs.contains(approval.id)
        return RoachPanel {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    RoachBadge(title: approval.typeTitle, accent: RoachTheme.primary)
                    if approval.status == "revision_requested" {
                        RoachBadge(title: "Sent back", accent: RoachTheme.amber)
                    }
                    Spacer()
                    if let created = approval.createdAt.flatMap(Self.parseDate) {
                        Text(formattedRelativeDate(created))
                            .font(RoachType.label)
                            .foregroundStyle(RoachTheme.softText)
                    }
                }
                Text(approval.headline)
                    .font(RoachType.itemTitle)
                    .foregroundStyle(RoachTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(approval.detailLines, id: \.0) { line in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(line.0)
                            .font(RoachType.label)
                            .foregroundStyle(RoachTheme.softText)
                            .frame(width: 84, alignment: .leading)
                        Text(line.1)
                            .font(RoachType.bodySmall)
                            .foregroundStyle(RoachTheme.subduedText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if model.orgCanDecide {
                    TextField(
                        "Note for the agent (optional)",
                        text: Binding(
                            get: { notes[approval.id] ?? "" },
                            set: { notes[approval.id] = $0 }
                        ), axis: .vertical
                    )
                    .font(RoachType.bodySmall)
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous).fill(RoachTheme.void.opacity(0.6))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(
                            RoachTheme.border, lineWidth: 1)
                    )
                    .accessibilityIdentifier("org.note.\(approval.id)")

                    HStack(spacing: 8) {
                        Button("Approve") { decide(approval, "approve") }
                            .buttonStyle(RoachButtonStyle(kind: .primary))
                            .accessibilityIdentifier("org.approve.\(approval.id)")
                        Button("Send back") { decide(approval, "request-revision") }
                            .buttonStyle(RoachButtonStyle(kind: .secondary))
                            .tint(RoachTheme.text)
                            .accessibilityIdentifier("org.revise.\(approval.id)")
                        Button("Reject") { decide(approval, "reject") }
                            .buttonStyle(RoachButtonStyle(kind: .danger))
                            .accessibilityIdentifier("org.reject.\(approval.id)")
                    }
                    .disabled(acting)
                } else {
                    Text("Only the board can decide this one.")
                        .font(RoachType.caption)
                        .foregroundStyle(RoachTheme.softText)
                }
            }
        }
        .opacity(acting ? 0.6 : 1)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("org.approval.\(approval.id)")
    }

    private func decide(_ approval: OrgApproval, _ decision: String) {
        let note = notes[approval.id]?.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await model.decideApproval(approval, decision: decision, note: note)
            notes[approval.id] = nil
        }
    }

    private var agentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoachOverline(text: "Agents", accent: RoachTheme.secondary)
            RoachPanel {
                VStack(spacing: 0) {
                    if model.orgAgents.isEmpty {
                        Text("No agents hired yet.")
                            .font(RoachType.body)
                            .foregroundStyle(RoachTheme.subduedText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    ForEach(Array(model.orgAgents.enumerated()), id: \.element.id) { index, agent in
                        if index > 0 { Divider().overlay(RoachTheme.border) }
                        HStack(spacing: 10) {
                            RoachStatusRow(
                                name: agent.name, subtitle: agent.errorReason ?? agent.pauseReason ?? agent.subtitle,
                                value: Self.statusTitle(agent.status), accent: Self.statusAccent(agent.status))
                            if model.orgCanDecide && agent.status != "terminated" {
                                let paused = agent.status == "paused"
                                Button(paused ? "Resume" : "Pause") {
                                    Task { await model.setOrgAgentStatus(agent, action: paused ? "resume" : "pause") }
                                }
                                .buttonStyle(RoachButtonStyle(kind: paused ? .signal : .secondary, size: .compact))
                                .tint(RoachTheme.text)
                                .disabled(model.orgActingIDs.contains(agent.id))
                                .accessibilityIdentifier("org.agent.\(paused ? "resume" : "pause").\(agent.id)")
                            }
                        }
                    }
                }
            }
        }
    }

    private func activitySection(_ dashboard: OrgDashboard) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            RoachOverline(text: "Logbook", accent: RoachTheme.cyan)
            RoachPanel {
                VStack(alignment: .leading, spacing: 10) {
                    if dashboard.recentActivity.isEmpty {
                        Text("Quiet so far.")
                            .font(RoachType.body)
                            .foregroundStyle(RoachTheme.subduedText)
                    }
                    ForEach(dashboard.recentActivity.prefix(6)) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(
                                item.createdAt.flatMap(Self.parseDate).map {
                                    $0.formatted(date: .omitted, time: .shortened)
                                } ?? "--:--"
                            )
                            .font(RoachType.code)
                            .foregroundStyle(RoachTheme.softText)
                            Text(item.title)
                                .font(RoachType.bodySmall)
                                .foregroundStyle(RoachTheme.text)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var joinForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            RoachSectionHeader(
                eyebrow: "RoachClaw Org",
                title: "Join your Org.",
                detail:
                    "Ask the owner for an invite on the Mac (Org › Members › Invite), then paste it here. They approve you from the Mac."
            )
            RoachPanel {
                VStack(alignment: .leading, spacing: 12) {
                    field("Invite", text: $model.orgInviteToken, prompt: "rninv_…", id: "org.join.token")
                    field("Your name", text: $joinName, prompt: "How the owner knows you", id: "org.join.name")
                    field("Email (optional)", text: $joinEmail, prompt: "you@example.com", id: "org.join.email")
                    Button {
                        Task { await model.acceptOrgInvite(name: joinName, email: joinEmail) }
                    } label: {
                        Text("Ask to join").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(RoachButtonStyle(kind: .primary))
                    .disabled(model.isLoadingOrg)
                    .accessibilityIdentifier("org.join.submit")
                }
            }
        }
    }

    private func field(_ label: String, text: Binding<String>, prompt: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .roachMonoCaps(RoachType.label, size: 10.5, tracking: 0.12)
                .foregroundStyle(RoachTheme.subduedText)
            TextField(prompt, text: text)
                .font(RoachType.body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(RoachTheme.void.opacity(0.6)))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(RoachTheme.border, lineWidth: 1)
                )
                .accessibilityIdentifier(id)
        }
    }

    static func statusTitle(_ status: String) -> String {
        switch status {
        case "running": return "Working"
        case "paused": return "Paused"
        case "error": return "Stuck"
        case "pending_approval": return "Awaiting OK"
        case "terminated": return "Retired"
        default: return "Idle"
        }
    }

    static func statusAccent(_ status: String) -> Color {
        switch status {
        case "running": return RoachTheme.secondary
        case "paused", "pending_approval": return RoachTheme.amber
        case "error": return RoachTheme.hazard
        case "terminated": return RoachTheme.softText
        default: return RoachTheme.cyan
        }
    }

    static func parseDate(_ raw: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }
}
