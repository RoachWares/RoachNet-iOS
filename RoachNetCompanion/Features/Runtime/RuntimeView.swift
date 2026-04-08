import SwiftUI

struct RuntimeView: View {
    @Bindable var model: CompanionAppModel

    var body: some View {
        NavigationStack {
            ZStack {
                RoachBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        connectionPanel
                        roachTailPanel
                        roachSyncPanel
                        machinePanel
                        roachClawPanel
                        servicesPanel
                        downloadsPanel
                        issuesPanel
                    }
                    .padding(16)
                }
                .refreshable {
                    await model.refreshAll()
                }
            }
            .navigationTitle("Runtime")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await model.refreshAll() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var roachTailPanel: some View {
        if let roachTail = model.runtime?.roachTail {
            RoachPanel {
                VStack(alignment: .leading, spacing: 12) {
                    RoachSectionHeader(
                        eyebrow: "RoachTail",
                        title: roachTail.enabled ? "Private device lane is \(roachTail.status)." : "Private device lane is off.",
                        detail: "RoachTail is the private overlay for mobile control, chat carryover, and remote installs."
                    )

                    HStack(spacing: 10) {
                        RoachMetricTile(
                            label: "Network",
                            value: roachTail.networkName,
                            accent: RoachTheme.primary
                        )

                        RoachMetricTile(
                            label: "Peers",
                            value: "\(roachTail.peers.count)",
                            accent: RoachTheme.secondary
                        )

                        RoachMetricTile(
                            label: "State",
                            value: roachTail.status.capitalized,
                            accent: roachTail.enabled ? RoachTheme.tertiary : RoachTheme.primary
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Toggle(
                                isOn: Binding(
                                    get: { model.runtime?.roachTail?.enabled ?? false },
                                    set: { nextValue in
                                        Task {
                                            await model.affectRoachTail(nextValue ? "enable" : "disable")
                                        }
                                    }
                                )
                            ) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("RoachTail")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(RoachTheme.text)
                                    Text(roachTail.enabled ? "Private overlay is armed." : "Private overlay is off.")
                                        .font(.caption)
                                        .foregroundStyle(RoachTheme.subduedText)
                                }
                            }
                            .toggleStyle(.switch)
                            .tint(RoachTheme.secondary)
                            .disabled(model.isActingRoachTail)

                            if !model.usingRoachTailPeerToken {
                                Button {
                                    Task { await model.affectRoachTail("refresh-join-code") }
                                } label: {
                                    Text("Refresh code")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .disabled(model.isActingRoachTail || !roachTail.enabled)
                            }
                        }

                        HStack(spacing: 10) {
                            Button {
                                Task {
                                    if model.roachTailIsLinked {
                                        await model.unlinkThisDeviceFromRoachTail()
                                    } else {
                                        await model.linkThisDeviceToRoachTail()
                                    }
                                }
                            } label: {
                                Text(model.roachTailIsLinked ? "Unlink this device" : "Link this device")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(model.isActingRoachTail || !roachTail.enabled)

                            if !model.usingRoachTailPeerToken {
                                Button {
                                    Task { await model.affectRoachTail("clear-peers") }
                                } label: {
                                    Text("Clear peers")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.bordered)
                                .disabled(model.isActingRoachTail || roachTail.peers.isEmpty)
                            }
                        }
                    }

                    if let advertisedUrl = roachTail.advertisedUrl, !advertisedUrl.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bridge")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(RoachTheme.secondary)
                            Text(advertisedUrl)
                                .font(.caption.monospaced())
                                .foregroundStyle(RoachTheme.text)
                                .textSelection(.enabled)
                        }
                    }

                    if let joinCode = roachTail.joinCode, !joinCode.isEmpty {
                        HStack(spacing: 8) {
                            Text("Join code")
                                .font(.caption)
                                .foregroundStyle(RoachTheme.subduedText)
                            Text(joinCode)
                                .font(.caption.monospaced().weight(.semibold))
                                .foregroundStyle(RoachTheme.text)
                        }
                    } else if model.usingRoachTailPeerToken {
                        Text("Join-code controls stay on the Mac or any device still using the desktop companion token.")
                            .font(.caption)
                            .foregroundStyle(RoachTheme.subduedText)
                    }

                    if !roachTail.peers.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Linked devices")
                                .font(.headline)
                                .foregroundStyle(RoachTheme.text)

                            ForEach(roachTail.peers.prefix(4)) { peer in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(peer.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(RoachTheme.text)
                                        Spacer()
                                        Text(peer.status.capitalized)
                                            .font(.caption)
                                            .foregroundStyle(RoachTheme.secondary)
                                    }

                                    Text("\(peer.platform) · \(peer.endpoint ?? "Peer lane ready")")
                                        .font(.caption)
                                        .foregroundStyle(RoachTheme.subduedText)

                                    if !peer.tags.isEmpty {
                                        Text(peer.tags.joined(separator: " · "))
                                            .font(.caption2)
                                            .foregroundStyle(RoachTheme.tertiary)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    if !roachTail.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(roachTail.notes.prefix(3), id: \.self) { note in
                                Text(note)
                                    .font(.caption)
                                    .foregroundStyle(RoachTheme.subduedText)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var roachSyncPanel: some View {
        if let roachSync = model.runtime?.roachSync {
            RoachPanel {
                VStack(alignment: .leading, spacing: 12) {
                    RoachSectionHeader(
                        eyebrow: "RoachSync",
                        title: roachSync.enabled ? "Contained sync lane is \(roachSync.status)." : "Contained sync lane is off.",
                        detail: "RoachSync keeps the vault and future shared state grouped under one private sync lane."
                    )

                    HStack(spacing: 10) {
                        RoachMetricTile(
                            label: "Network",
                            value: roachSync.networkName,
                            accent: RoachTheme.primary
                        )

                        RoachMetricTile(
                            label: "Peers",
                            value: "\(roachSync.peers.count)",
                            accent: RoachTheme.secondary
                        )

                        RoachMetricTile(
                            label: "State",
                            value: roachSync.status.capitalized,
                            accent: roachSync.enabled ? RoachTheme.tertiary : RoachTheme.primary
                        )
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Toggle(
                            isOn: Binding(
                                get: { model.runtime?.roachSync?.enabled ?? false },
                                set: { nextValue in
                                    Task {
                                        await model.affectRoachSync(nextValue ? "enable" : "disable")
                                    }
                                }
                            )
                        ) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("RoachSync")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(RoachTheme.text)
                                Text(roachSync.enabled ? "Contained sync lane is armed." : "Contained sync lane is off.")
                                    .font(.caption)
                                    .foregroundStyle(RoachTheme.subduedText)
                            }
                        }
                        .toggleStyle(.switch)
                        .tint(RoachTheme.secondary)
                        .disabled(model.isActingRoachSync)

                        HStack(spacing: 10) {
                            Button {
                                Task { await model.affectRoachSync("refresh") }
                            } label: {
                                Text("Refresh sync")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(model.isActingRoachSync)

                            Button {
                                Task { await model.affectRoachSync("clear-peers") }
                            } label: {
                                Text("Clear peers")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .disabled(model.isActingRoachSync || roachSync.peers.isEmpty)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Folder")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(RoachTheme.secondary)
                        Text(roachSync.folderPath)
                            .font(.caption.monospaced())
                            .foregroundStyle(RoachTheme.text)
                            .textSelection(.enabled)
                    }

                    if !roachSync.peers.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Synced devices")
                                .font(.headline)
                                .foregroundStyle(RoachTheme.text)

                            ForEach(roachSync.peers.prefix(4)) { peer in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(peer.name)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(RoachTheme.text)
                                        Spacer()
                                        Text(peer.status.capitalized)
                                            .font(.caption)
                                            .foregroundStyle(RoachTheme.secondary)
                                    }

                                    Text(peer.lastSeenAt.map(formattedRelativeDate) ?? "Contained sync lane ready")
                                        .font(.caption)
                                        .foregroundStyle(RoachTheme.subduedText)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    if !roachSync.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(roachSync.notes.prefix(3), id: \.self) { note in
                                Text(note)
                                    .font(.caption)
                                    .foregroundStyle(RoachTheme.subduedText)
                            }
                        }
                    }
                }
            }
        }
    }

    private var connectionPanel: some View {
        RoachPanel {
            VStack(alignment: .leading, spacing: 12) {
                RoachSectionHeader(
                    eyebrow: "Companion lane",
                    title: model.connection.isConfigured ? "Phone to Mac link is live." : "Pair the desktop first.",
                    detail: "Runtime status, service controls, and RoachClaw all run through the same companion bridge."
                )

                HStack(spacing: 10) {
                    RoachMetricTile(
                        label: "URL",
                        value: model.connection.baseURL,
                        accent: RoachTheme.tertiary
                    )

                    RoachMetricTile(
                        label: "Token",
                        value: model.connection.isConfigured
                            ? (model.usingRoachTailPeerToken ? "RoachTail peer" : "Desktop token")
                            : "Missing",
                        accent: model.connection.isConfigured ? RoachTheme.secondary : RoachTheme.primary
                    )
                }

                if model.pairedMachineName != nil {
                    Text("Paired desktop linked.")
                        .font(.caption)
                        .foregroundStyle(RoachTheme.subduedText)
                } else if !model.connection.isConfigured {
                    Text("Previewing the runtime lane until you pair the Mac.")
                        .font(.caption)
                        .foregroundStyle(RoachTheme.subduedText)
                }

                if let lastRefreshAt = model.lastRefreshAt {
                    Text("Last sync \(formattedRelativeDate(lastRefreshAt))")
                        .font(.caption)
                        .foregroundStyle(RoachTheme.secondary)
                }
            }
        }
    }

    private var machinePanel: some View {
        RoachPanel {
            VStack(alignment: .leading, spacing: 12) {
                RoachSectionHeader(
                    eyebrow: "Machine",
                    title: model.runtime?.systemInfo?.hardwareProfile?.platformLabel ?? "RoachNet desktop",
                    detail: model.runtime?.systemInfo?.hardwareProfile?.recommendedModelClass ?? "Model guidance is not available yet."
                )

                HStack(spacing: 10) {
                    if let available = model.runtime?.systemInfo?.mem?.available {
                        RoachMetricTile(
                            label: "Memory",
                            value: formattedBytes(Int64(available)),
                            accent: RoachTheme.secondary
                        )
                    }

                    RoachMetricTile(
                        label: "Services",
                        value: "\(model.runtime?.services.count ?? 0)",
                        accent: RoachTheme.tertiary
                    )
                }

                if let notes = model.runtime?.systemInfo?.hardwareProfile?.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(notes.prefix(3), id: \.self) { note in
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(RoachTheme.subduedText)
                        }
                    }
                }
            }
        }
    }

    private var roachClawPanel: some View {
        RoachPanel {
            VStack(alignment: .leading, spacing: 12) {
                RoachSectionHeader(
                    eyebrow: "RoachClaw",
                    title: (model.runtime?.roachClaw.ready ?? false) ? "Local AI lane is ready." : "RoachClaw is warming up.",
                    detail: model.runtime?.roachClaw.error ?? "Model selection, installed packs, and provider state all show here."
                )

                HStack(spacing: 10) {
                    RoachMetricTile(
                        label: "State",
                        value: (model.runtime?.roachClaw.ready ?? false) ? "Ready" : "Booting",
                        accent: (model.runtime?.roachClaw.ready ?? false) ? RoachTheme.secondary : RoachTheme.primary
                    )

                    RoachMetricTile(
                        label: "Model",
                        value: model.runtime?.roachClaw.resolvedDefaultModel ?? model.runtime?.roachClaw.defaultModel ?? "Not set",
                        accent: RoachTheme.tertiary
                    )
                }

                if let installedModels = model.runtime?.installedModels, !installedModels.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Installed models")
                            .font(.headline)
                            .foregroundStyle(RoachTheme.text)

                        ForEach(installedModels.prefix(6)) { model in
                            HStack {
                                Text(model.name)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(RoachTheme.text)
                                Spacer()
                                Text(formattedBytes(model.size))
                                    .font(.caption2)
                                    .foregroundStyle(RoachTheme.subduedText)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var servicesPanel: some View {
        if let services = model.runtime?.services, !services.isEmpty {
            RoachPanel {
                VStack(alignment: .leading, spacing: 12) {
                    RoachSectionHeader(
                        eyebrow: "Services",
                        title: "Control the desktop lane from here.",
                        detail: "Restart or stop pieces of the runtime without leaving the phone."
                    )

                    ForEach(services.prefix(6)) { service in
                        serviceRow(service)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var downloadsPanel: some View {
        if let downloads = model.runtime?.downloads, !downloads.isEmpty {
            RoachPanel {
                VStack(alignment: .leading, spacing: 10) {
                    RoachSectionHeader(
                        eyebrow: "Downloads",
                        title: "Current install queue.",
                        detail: "These are the active jobs on the paired desktop."
                    )

                    ForEach(downloads.prefix(5)) { job in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(job.filepath ?? job.jobId)
                                .font(.caption.monospaced())
                                .foregroundStyle(RoachTheme.text)
                                .lineLimit(1)

                            HStack {
                                Text(job.status ?? "Queued")
                                    .font(.caption)
                                    .foregroundStyle(RoachTheme.subduedText)
                                Spacer()
                                Text(job.progress.map { "\($0)%" } ?? "--")
                                    .font(.caption)
                                    .foregroundStyle(RoachTheme.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var issuesPanel: some View {
        if !model.runtimeIssues.isEmpty {
            RoachPanel {
                VStack(alignment: .leading, spacing: 10) {
                    RoachSectionHeader(
                        eyebrow: "Runtime notes",
                        title: "A few things need attention.",
                        detail: nil
                    )

                    ForEach(model.runtimeIssues) { issue in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(issue.path)
                                .font(.caption.monospaced())
                                .foregroundStyle(RoachTheme.secondary)
                            Text(issue.error)
                                .font(.caption)
                                .foregroundStyle(RoachTheme.subduedText)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func serviceRow(_ service: CompanionService) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(service.friendlyName ?? service.serviceName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(RoachTheme.text)

                    Text(service.status ?? "Unknown state")
                        .font(.caption)
                        .foregroundStyle(RoachTheme.subduedText)
                }

                Spacer()

                RoachBadge(
                    title: (service.installed ?? false) ? "Installed" : "Optional",
                    accent: (service.installed ?? false) ? RoachTheme.secondary : RoachTheme.tertiary
                )
            }

            HStack(spacing: 8) {
                runtimeActionButton(title: "Start", service: service.serviceName, action: "start")
                runtimeActionButton(title: "Restart", service: service.serviceName, action: "restart")
                runtimeActionButton(title: "Stop", service: service.serviceName, action: "stop")
            }
        }
    }

    private func runtimeActionButton(title: String, service: String, action: String) -> some View {
        Button(title) {
            Task {
                await model.affectService(service, action: action)
            }
        }
        .buttonStyle(.bordered)
        .tint(action == "stop" ? RoachTheme.primary : RoachTheme.secondary)
        .disabled(model.actingServiceNames.contains(service))
    }
}
