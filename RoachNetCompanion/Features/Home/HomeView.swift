import SwiftUI

/// Home: the phone's mission control for the paired Mac (RoachNet v4 iOS mockup).
struct HomeView: View {
    @Bindable var model: CompanionAppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                hero
                metrics
                vitalSigns
                orgCard
                quickActions
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, RoachCompanionChrome.bottomContentClearance)
            .frame(maxWidth: 760)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .refreshable { await model.refreshAll() }
        .accessibilityIdentifier("screen.home")
    }

    // MARK: Header and hero

    private var header: some View {
        HStack(spacing: 10) {
            RoachDot(accent: isLive ? RoachTheme.secondary : RoachTheme.amber)
            Text("RoachNet")
                .roachDisplay(20)
                .foregroundStyle(RoachTheme.text)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Button {
                model.settingsPresented = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(RoachButtonStyle(kind: .secondary, size: .compact))
            .tint(RoachTheme.text)
            .accessibilityLabel("Connection")
            .accessibilityIdentifier("home.connection")
        }
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            RoachOverline(text: isLive ? "Synced with \(model.pairedMachineName ?? "your Mac")" : "Preview mode")
            Text(isLive ? "Your bunker, pocket-sized." : "Your Mac, in your pocket.")
                .roachDisplay(36)
                .foregroundStyle(RoachTheme.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text(isLive
                 ? "Maps, library, vault and RoachClaw from your Mac, over your own network. No middleman, no account."
                 : "Pair with RoachNet on your Mac to bring its AI, library and vault here. Nothing goes through anyone else's server.")
                .font(RoachType.lede)
                .foregroundStyle(RoachTheme.subduedText)
                .fixedSize(horizontal: false, vertical: true)

            if !model.connection.isConfigured {
                Button {
                    model.settingsPresented = true
                } label: {
                    Label("Pair your Mac", systemImage: "link")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(RoachButtonStyle(kind: .primary))
                .accessibilityIdentifier("home.pairMac")
                .padding(.top, 4)
            }
        }
        .padding(.top, 6)
    }

    // MARK: Metrics and vital signs

    private var metrics: some View {
        RoachMetricRow {
            RoachMetricTile(label: "Brains", value: "\(model.runtime?.installedModels.count ?? 0)", accent: RoachTheme.secondary)
            RoachMetricTile(label: "Shelves", value: "\(shelfCount)", accent: RoachTheme.cyan)
            RoachMetricTile(label: "Archives", value: "\(model.vault?.siteArchives.count ?? 0)", accent: RoachTheme.primary)
        }
    }

    private var vitalSigns: some View {
        RoachPanel {
            VStack(alignment: .leading, spacing: 0) {
                RoachOverline(text: "Vital signs", accent: RoachTheme.cyan)
                    .padding(.bottom, 4)
                RoachStatusRow(
                    name: isLive ? "Linked to \(model.pairedMachineName ?? "your Mac")" : "Not paired yet",
                    subtitle: isLive ? model.connection.securityDetail : "Everything here is sample data until you pair.",
                    value: isLive ? "Live" : "Preview",
                    accent: isLive ? RoachTheme.secondary : RoachTheme.amber
                )
                Divider().overlay(RoachTheme.border)
                RoachStatusRow(
                    name: "Brain on your Mac",
                    subtitle: brainSubtitle,
                    value: brainReady ? "Ready" : (isLive ? "Warming up" : "Idle"),
                    accent: brainReady ? RoachTheme.secondary : RoachTheme.purpleInk
                )
                Divider().overlay(RoachTheme.border)
                RoachStatusRow(
                    name: "RoachTail",
                    subtitle: model.usingRoachTailPeerToken ? "This phone has its own private token." : "Pair over RoachTail for a per-device token.",
                    value: (model.runtime?.roachTail?.enabled ?? false) ? "Armed" : "Off",
                    accent: (model.runtime?.roachTail?.enabled ?? false) ? RoachTheme.secondary : RoachTheme.softText
                )
                if !model.runtimeIssues.isEmpty {
                    Divider().overlay(RoachTheme.border)
                    RoachStatusRow(
                        name: "\(model.runtimeIssues.count) thing\(model.runtimeIssues.count == 1 ? "" : "s") need attention",
                        subtitle: model.runtimeIssues.first?.error,
                        value: "Check",
                        accent: RoachTheme.hazard
                    )
                }
            }
        }
        .accessibilityIdentifier("home.vitalSigns")
    }

    // MARK: Org

    @ViewBuilder
    private var orgCard: some View {
        let pending = model.pendingOrgApprovals.count
        RoachHeroPanel(accent: pending > 0 ? RoachTheme.primary : RoachTheme.cyan) {
            VStack(alignment: .leading, spacing: 10) {
                RoachOverline(text: "RoachClaw Org", accent: pending > 0 ? RoachTheme.primary : RoachTheme.cyan)
                Text(orgTitle(pending: pending))
                    .font(RoachType.cardTitle)
                    .foregroundStyle(RoachTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(orgDetail)
                    .font(RoachType.bodySmall)
                    .foregroundStyle(RoachTheme.subduedText)
                    .fixedSize(horizontal: false, vertical: true)
                if model.orgAvailability != .unsupported {
                    Button {
                        model.orgPresented = true
                    } label: {
                        Text(pending > 0 ? "Review approvals" : "Open Org")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(RoachButtonStyle(kind: pending > 0 ? .primary : .secondary))
                    .tint(RoachTheme.text)
                    .accessibilityIdentifier("home.openOrg")
                }
            }
        }
    }

    private func orgTitle(pending: Int) -> String {
        switch model.orgAvailability {
        case .unsupported: return "Org arrives with RoachNet 1.1."
        case .needsInvite: return "Join your Org."
        case .pendingApproval(let company): return "Waiting on \(company)."
        default:
            if pending > 0 { return "\(pending) approval\(pending == 1 ? "" : "s") waiting." }
            if let dashboard = model.orgDashboard { return "\(dashboard.company.name) is humming." }
            return "Your agent company."
        }
    }

    private var orgDetail: String {
        switch model.orgAvailability {
        case .unsupported: return "Update RoachNet on your Mac to run an agent company and approve its work from here."
        case .needsInvite: return "Ask the owner for an invite on the Mac, then paste it here."
        case .pendingApproval: return "The owner approves new members on the Mac. You'll see the company here once they do."
        default:
            if let dashboard = model.orgDashboard {
                return "\(dashboard.activeAgents) agents · \(dashboard.openIssues) open issues · \(dashboard.runningRuns) running now"
            }
            return "Hire agents, set budgets and approve their work. It all runs on your Mac."
        }
    }

    // MARK: Quick actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            RoachOverline(text: "Go anywhere", accent: RoachTheme.secondary)
            quickAction("Ask RoachClaw", "message.fill", RoachTheme.primary, .chat)
            quickAction("Install to your Mac", "square.grid.2x2.fill", RoachTheme.tertiary, .apps)
            quickAction("Open the vault", "archivebox.fill", RoachTheme.secondary, .vault)
            quickAction("The engine room", "switch.2", RoachTheme.cyan, .runtime)
        }
    }

    private func quickAction(_ title: String, _ icon: String, _ accent: Color, _ tab: CompanionTab) -> some View {
        Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.8)) { model.selectedTab = tab }
        } label: {
            RoachActionPill(title: title, systemImage: icon, accent: accent)
        }
        .buttonStyle(RoachPressableButtonStyle())
        .accessibilityIdentifier("home.go.\(tab.identifier)")
    }

    // MARK: Derived

    private var isLive: Bool {
        model.connection.isConfigured && model.runtime != nil && !CompanionLaunchOptions.forceDemoMode
    }

    private var brainReady: Bool { model.runtime?.roachClaw.ready ?? false }

    private var brainSubtitle: String {
        if let name = model.activeModelName, !name.isEmpty { return "\(name). Ask from here; it thinks there." }
        return "No model yet. Pick one on your Mac."
    }

    private var shelfCount: Int {
        guard let vault = model.vault else { return 0 }
        return vault.atlasShelves.count + vault.studyShelves.count + vault.referenceShelves.count
    }
}
