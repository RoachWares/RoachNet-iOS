@preconcurrency import CoreBluetooth
import CoreLocation
import Foundation
import SwiftUI

struct RuntimeView: View {
    @Bindable var model: CompanionAppModel
    @StateObject private var phoneGPS = RoachPhoneGPSAdvertiser()

    var body: some View {
        NavigationStack {
            ZStack {
                RoachBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        overviewPanel
                        connectionPanel
                        accountPanel
                        roachTailPanel
                        phoneGPSPanel
                        roachSyncPanel
                        machinePanel
                        roachClawPanel
                        servicesPanel
                        downloadsPanel
                        issuesPanel
                    }
                    .padding(16)
                    .padding(.bottom, RoachCompanionChrome.bottomContentClearance)
                }
                .roachTabBarScrollClearance()
                .refreshable {
                    await model.refreshAll()
                }
            }
            .navigationBarHidden(true)
        }
    }

    private var overviewPanel: some View {
        RoachHeroPanel(accent: RoachTheme.secondary) {
            VStack(alignment: .leading, spacing: 16) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 14) {
                            VStack(alignment: .leading, spacing: 6) {
                                RoachSectionHeader(
                                    eyebrow: "Runtime",
                                    title: "Contained stack. No mystery boxes.",
                                    detail: "RoachTail, RoachSync, account state, and the local runtime stay in one readable control surface."
                                )

                                if let lastRefreshAt = model.lastRefreshAt {
                                    Text("Last sync \(formattedRelativeDate(lastRefreshAt))")
                                        .font(RoachType.caption)
                                        .foregroundStyle(RoachTheme.subduedText)
                                }
                            }

                            runtimePills
                        }

                        Spacer(minLength: 12)

                        VStack(alignment: .trailing, spacing: 12) {
                            Button {
                                Task { await model.refreshAll() }
                            } label: {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(RoachButtonStyle(kind: .secondary, size: .compact))
                            .tint(RoachTheme.secondary)

                            runtimeSignals
                                .frame(width: 280, alignment: .trailing)
                        }
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        VStack(alignment: .leading, spacing: 6) {
                            RoachSectionHeader(
                                eyebrow: "Runtime",
                                title: "Contained stack. No mystery boxes.",
                                detail: "RoachTail, RoachSync, account state, and the local runtime stay in one readable control surface."
                            )

                            if let lastRefreshAt = model.lastRefreshAt {
                                Text("Last sync \(formattedRelativeDate(lastRefreshAt))")
                                    .font(RoachType.caption)
                                    .foregroundStyle(RoachTheme.subduedText)
                            }
                        }

                        runtimePills
                        runtimeSignals

                        Button {
                            Task { await model.refreshAll() }
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(RoachButtonStyle(kind: .secondary, size: .compact))
                        .tint(RoachTheme.secondary)
                    }
                }
            }
        }
    }

    private var phoneGPSPanel: some View {
        RoachPanel {
            VStack(alignment: .leading, spacing: 12) {
                RoachSectionHeader(
                    eyebrow: "RoachAtlas",
                    title: phoneGPS.isRunning ? "iPhone GPS is advertising." : "Share live GPS with the Mac.",
                    detail: "Foreground BLE only. The phone sends a local RoachAtlas packet to the paired desktop receiver; it does not upload location through RoachNet."
                )

                RoachMetricRow {
                    RoachMetricTile(
                        label: "Bridge",
                        value: phoneGPS.state.label,
                        accent: phoneGPS.state.accent
                    )
                    RoachMetricTile(
                        label: "Fix",
                        value: phoneGPS.latestFix?.coordinateLabel ?? "No fix",
                        accent: phoneGPS.latestFix == nil ? RoachTheme.primary : RoachTheme.secondary
                    )
                    RoachMetricTile(
                        label: "Packets",
                        value: "\(phoneGPS.packetCount)",
                        accent: RoachTheme.tertiary
                    )
                }

                HStack(spacing: 10) {
                    Image(systemName: phoneGPS.isRunning ? "location.fill" : "location")
                        .font(RoachType.headline())
                        .foregroundStyle(phoneGPS.state.accent)
                        .frame(width: 38, height: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(phoneGPS.state.accent.opacity(0.14))
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(phoneGPS.state.detail)
                            .font(RoachType.subheadline(.semibold))
                            .foregroundStyle(RoachTheme.text)
                        Text(phoneGPS.latestFix.map { "Accuracy \($0.accuracyLabel) · \($0.ageLabel)" } ?? "No location leaves the phone until you start this bridge.")
                            .font(RoachType.caption)
                            .foregroundStyle(RoachTheme.subduedText)
                    }

                    Spacer(minLength: 0)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        Button {
                            phoneGPS.isRunning ? phoneGPS.stop() : phoneGPS.start()
                        } label: {
                            Label(phoneGPS.isRunning ? "Stop GPS" : "Start GPS", systemImage: phoneGPS.isRunning ? "stop.fill" : "antenna.radiowaves.left.and.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(RoachButtonStyle(kind: .primary, size: .compact))
                        .tint(phoneGPS.isRunning ? RoachTheme.primary : RoachTheme.secondary)

                        Button {
                            phoneGPS.publishDemoFix()
                        } label: {
                            Label("Demo packet", systemImage: "location.north.line")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(RoachButtonStyle(kind: .secondary, size: .compact))
                        .tint(RoachTheme.tertiary)
                    }

                    VStack(spacing: 10) {
                        Button {
                            phoneGPS.isRunning ? phoneGPS.stop() : phoneGPS.start()
                        } label: {
                            Label(phoneGPS.isRunning ? "Stop GPS" : "Start GPS", systemImage: phoneGPS.isRunning ? "stop.fill" : "antenna.radiowaves.left.and.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(RoachButtonStyle(kind: .primary, size: .compact))
                        .tint(phoneGPS.isRunning ? RoachTheme.primary : RoachTheme.secondary)

                        Button {
                            phoneGPS.publishDemoFix()
                        } label: {
                            Label("Demo packet", systemImage: "location.north.line")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(RoachButtonStyle(kind: .secondary, size: .compact))
                        .tint(RoachTheme.tertiary)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $phoneGPS.highAccuracy) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Precise drive mode")
                                .font(RoachType.subheadline(.semibold))
                                .foregroundStyle(RoachTheme.text)
                            Text("Uses the best foreground location accuracy while the bridge is running.")
                                .font(RoachType.caption)
                                .foregroundStyle(RoachTheme.subduedText)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(RoachTheme.secondary)

                    Toggle(isOn: $phoneGPS.includeMotionDetails) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Include speed, heading, altitude")
                                .font(RoachType.subheadline(.semibold))
                                .foregroundStyle(RoachTheme.text)
                            Text("RoachAtlas can draw richer traces; turn it off for a lean lat/lon packet.")
                                .font(RoachType.caption)
                                .foregroundStyle(RoachTheme.subduedText)
                        }
                    }
                    .toggleStyle(.switch)
                    .tint(RoachTheme.tertiary)
                }

                if let packet = phoneGPS.lastPacket, !packet.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Packet")
                            .font(RoachType.caption(.semibold))
                            .foregroundStyle(RoachTheme.secondary)
                        Text(packet)
                            .font(RoachType.mono(11, relativeTo: .caption2))
                            .foregroundStyle(RoachTheme.subduedText)
                            .lineLimit(3)
                            .textSelection(.enabled)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("BLE contract")
                        .font(RoachType.caption(.semibold))
                        .foregroundStyle(RoachTheme.secondary)
                    Text("\(RoachPhoneGPSAdvertiser.gpsServiceUUIDString) · \(RoachPhoneGPSAdvertiser.gpsCharacteristicUUIDString)")
                        .font(RoachType.mono(11, relativeTo: .caption2))
                        .foregroundStyle(RoachTheme.subduedText)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var runtimePills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                RoachStatusPill(
                    title: model.runtime?.account?.linked == true ? "Account linked" : "Account local",
                    accent: model.runtime?.account?.linked == true ? RoachTheme.tertiary : RoachTheme.primary
                )
                RoachStatusPill(
                    title: model.runtime?.roachTail?.enabled == true ? "RoachTail armed" : "RoachTail off",
                    accent: model.runtime?.roachTail?.enabled == true ? RoachTheme.secondary : RoachTheme.primary
                )
                RoachStatusPill(
                    title: model.runtime?.roachSync?.enabled == true ? "RoachSync armed" : "RoachSync off",
                    accent: model.runtime?.roachSync?.enabled == true ? RoachTheme.secondary : RoachTheme.primary
                )
                RoachStatusPill(
                    title: model.connection.isConfigured ? "Bridge ready" : "Bridge local-only",
                    accent: model.connection.isConfigured ? RoachTheme.tertiary : RoachTheme.primary
                )
            }
            .padding(.vertical, 1)
        }
    }

    private var runtimeSignals: some View {
        let hasLiveService = model.runtime?.services.contains(where: {
            ($0.status ?? "").localizedCaseInsensitiveContains("live") ||
            ($0.status ?? "").localizedCaseInsensitiveContains("running")
        }) == true

        return LazyVGrid(
            columns: [
                GridItem(.flexible(minimum: 0), spacing: 10),
                GridItem(.flexible(minimum: 0), spacing: 10),
            ],
            alignment: .leading,
            spacing: 10
        ) {
            RoachSignalTile(
                label: "Runtime",
                value: hasLiveService ? "Live" : "Local",
                accent: hasLiveService ? RoachTheme.secondary : RoachTheme.primary,
                systemImage: "switch.2"
            )
            RoachSignalTile(
                label: "Services",
                value: "\(model.runtime?.services.count ?? 0)",
                accent: RoachTheme.tertiary,
                systemImage: "server.rack"
            )
            RoachSignalTile(
                label: "Downloads",
                value: "\(model.runtime?.downloads.count ?? 0)",
                accent: RoachTheme.primary,
                systemImage: "arrow.down.circle"
            )
            RoachSignalTile(
                label: "Issues",
                value: "\(model.runtimeIssues.count)",
                accent: model.runtimeIssues.isEmpty ? RoachTheme.secondary : RoachTheme.primary,
                systemImage: "exclamationmark.triangle"
            )
        }
    }

    @ViewBuilder
    private var accountPanel: some View {
        if let account = model.runtime?.account {
            RoachPanel {
                VStack(alignment: .leading, spacing: 12) {
                    RoachSectionHeader(
                        eyebrow: "Account",
                        title: account.linked ? "Account lane is linked." : "Account lane is still local-only.",
                        detail: "RoachClaw web chat, synced settings, and saved app picks can ride the same contained identity."
                    )

                    RoachMetricRow {
                        RoachMetricTile(
                            label: "State",
                            value: account.status.capitalized,
                            accent: account.linked ? RoachTheme.secondary : RoachTheme.primary
                        )

                        RoachMetricTile(
                            label: "Settings",
                            value: account.settingsSyncEnabled ? "Synced" : "Local",
                            accent: account.settingsSyncEnabled ? RoachTheme.tertiary : RoachTheme.primary
                        )

                        RoachMetricTile(
                            label: "Apps",
                            value: account.savedAppsSyncEnabled ? "Synced" : "Local",
                            accent: account.savedAppsSyncEnabled ? RoachTheme.tertiary : RoachTheme.primary
                        )
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Alias")
                            .font(RoachType.caption(.semibold))
                            .foregroundStyle(RoachTheme.secondary)
                        Text(account.aliasHost)
                            .font(RoachType.mono(12, relativeTo: .caption))
                            .foregroundStyle(RoachTheme.text)
                    }

                    if let bridgeUrl = account.bridgeUrl, !bridgeUrl.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bridge")
                                .font(RoachType.caption(.semibold))
                                .foregroundStyle(RoachTheme.secondary)
                            Text(bridgeUrl)
                                .font(RoachType.mono(12, relativeTo: .caption))
                                .foregroundStyle(RoachTheme.text)
                                .textSelection(.enabled)
                        }
                    }

                    if !account.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(account.notes.prefix(3), id: \.self) { note in
                                Text(note)
                                    .font(RoachType.caption)
                                    .foregroundStyle(RoachTheme.subduedText)
                            }
                        }
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
                        detail: "RoachTail is the private overlay for mobile control, thread carryover, and remote installs."
                    )

                    RoachMetricRow {
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

                    VStack(alignment: .leading, spacing: 10) {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 10) {
                                roachTailToggle(roachTail)

                                if !model.usingRoachTailPeerToken {
                                    Button {
                                        Task { await model.affectRoachTail("refresh-join-code") }
                                    } label: {
                                        Text("Refresh code")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(RoachButtonStyle(kind: .secondary, size: .compact))
                                    .tint(RoachTheme.tertiary)
                                    .disabled(model.isActingRoachTail || !roachTail.enabled)
                                }
                            }

                            VStack(spacing: 10) {
                                roachTailToggle(roachTail)

                                if !model.usingRoachTailPeerToken {
                                    Button {
                                        Task { await model.affectRoachTail("refresh-join-code") }
                                    } label: {
                                        Text("Refresh code")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(RoachButtonStyle(kind: .secondary, size: .compact))
                                    .tint(RoachTheme.tertiary)
                                    .disabled(model.isActingRoachTail || !roachTail.enabled)
                                }
                            }
                        }

                        ViewThatFits(in: .horizontal) {
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
                                .buttonStyle(RoachButtonStyle(kind: .secondary, size: .compact))
                                .tint(model.roachTailIsLinked ? RoachTheme.primary : RoachTheme.secondary)
                                .disabled(model.isActingRoachTail || !roachTail.enabled)

                                if !model.usingRoachTailPeerToken {
                                    Button {
                                        Task { await model.affectRoachTail("clear-peers") }
                                    } label: {
                                        Text("Clear peers")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(RoachButtonStyle(kind: .secondary, size: .compact))
                                    .tint(RoachTheme.primary)
                                    .disabled(model.isActingRoachTail || roachTail.peers.isEmpty)
                                }
                            }

                            VStack(spacing: 10) {
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
                                .buttonStyle(RoachButtonStyle(kind: .secondary, size: .compact))
                                .tint(model.roachTailIsLinked ? RoachTheme.primary : RoachTheme.secondary)
                                .disabled(model.isActingRoachTail || !roachTail.enabled)

                                if !model.usingRoachTailPeerToken {
                                    Button {
                                        Task { await model.affectRoachTail("clear-peers") }
                                    } label: {
                                        Text("Clear peers")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(RoachButtonStyle(kind: .secondary, size: .compact))
                                    .tint(RoachTheme.primary)
                                    .disabled(model.isActingRoachTail || roachTail.peers.isEmpty)
                                }
                            }
                        }
                    }

                    if let advertisedUrl = roachTail.advertisedUrl, !advertisedUrl.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Bridge")
                                .font(RoachType.caption(.semibold))
                                .foregroundStyle(RoachTheme.secondary)
                            Text(advertisedUrl)
                                .font(RoachType.mono(12, relativeTo: .caption))
                                .foregroundStyle(RoachTheme.text)
                                .textSelection(.enabled)
                        }
                    }

                    if let joinCode = roachTail.joinCode, !joinCode.isEmpty {
                        HStack(spacing: 8) {
                            Text("Join code")
                                .font(RoachType.caption)
                                .foregroundStyle(RoachTheme.subduedText)
                            Text(joinCode)
                                .font(RoachType.mono(12, relativeTo: .caption).weight(.semibold))
                                .foregroundStyle(RoachTheme.text)
                        }
                    } else if model.usingRoachTailPeerToken {
                        Text("Join-code controls stay on the Mac or any device still using the desktop companion token.")
                            .font(RoachType.caption)
                            .foregroundStyle(RoachTheme.subduedText)
                    }

                    if !roachTail.peers.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Linked devices")
                                .font(RoachType.headline())
                                .foregroundStyle(RoachTheme.text)

                            ForEach(roachTail.peers.prefix(4)) { peer in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(peer.name)
                                            .font(RoachType.subheadline(.semibold))
                                            .foregroundStyle(RoachTheme.text)
                                        Spacer()
                                        Text(peer.status.capitalized)
                                            .font(RoachType.caption)
                                            .foregroundStyle(RoachTheme.secondary)
                                    }

                                    Text("\(peer.platform) · \(peer.endpoint ?? "Peer lane ready")")
                                        .font(RoachType.caption)
                                        .foregroundStyle(RoachTheme.subduedText)

                                    if !peer.tags.isEmpty {
                                        Text(peer.tags.joined(separator: " · "))
                                            .font(RoachType.caption2)
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
                                    .font(RoachType.caption)
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

                    RoachMetricRow {
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
                                    .font(RoachType.subheadline(.semibold))
                                    .foregroundStyle(RoachTheme.text)
                                Text(roachSync.enabled ? "Contained sync lane is armed." : "Contained sync lane is off.")
                                    .font(RoachType.caption)
                                    .foregroundStyle(RoachTheme.subduedText)
                            }
                        }
                        .toggleStyle(.switch)
                        .tint(RoachTheme.secondary)
                        .disabled(model.isActingRoachSync)

                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 10) {
                                Button {
                                    Task { await model.affectRoachSync("refresh") }
                                } label: {
                                    Text("Refresh sync")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(RoachButtonStyle(kind: .secondary, size: .compact))
                                .disabled(model.isActingRoachSync)

                                Button {
                                    Task { await model.affectRoachSync("clear-peers") }
                                } label: {
                                    Text("Clear peers")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(RoachButtonStyle(kind: .secondary, size: .compact))
                                .disabled(model.isActingRoachSync || roachSync.peers.isEmpty)
                            }

                            VStack(spacing: 10) {
                                Button {
                                    Task { await model.affectRoachSync("refresh") }
                                } label: {
                                    Text("Refresh sync")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(RoachButtonStyle(kind: .secondary, size: .compact))
                                .disabled(model.isActingRoachSync)

                                Button {
                                    Task { await model.affectRoachSync("clear-peers") }
                                } label: {
                                    Text("Clear peers")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(RoachButtonStyle(kind: .secondary, size: .compact))
                                .disabled(model.isActingRoachSync || roachSync.peers.isEmpty)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Folder")
                            .font(RoachType.caption(.semibold))
                            .foregroundStyle(RoachTheme.secondary)
                        Text(roachSync.folderPath)
                            .font(RoachType.mono(12, relativeTo: .caption))
                            .foregroundStyle(RoachTheme.text)
                            .textSelection(.enabled)
                    }

                    if !roachSync.peers.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Synced devices")
                                .font(RoachType.headline())
                                .foregroundStyle(RoachTheme.text)

                            ForEach(roachSync.peers.prefix(4)) { peer in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(peer.name)
                                            .font(RoachType.subheadline(.semibold))
                                            .foregroundStyle(RoachTheme.text)
                                        Spacer()
                                        Text(peer.status.capitalized)
                                            .font(RoachType.caption)
                                            .foregroundStyle(RoachTheme.secondary)
                                    }

                                    Text(peer.lastSeenAt.map(formattedRelativeDate) ?? "Contained sync lane ready")
                                        .font(RoachType.caption)
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
                                    .font(RoachType.caption)
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

                RoachMetricRow {
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
                        .font(RoachType.caption)
                        .foregroundStyle(RoachTheme.subduedText)
                } else if !model.connection.isConfigured {
                    Text("Previewing the runtime lane until you pair the Mac.")
                        .font(RoachType.caption)
                        .foregroundStyle(RoachTheme.subduedText)
                }

                if let lastRefreshAt = model.lastRefreshAt {
                    Text("Last sync \(formattedRelativeDate(lastRefreshAt))")
                        .font(RoachType.caption)
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

                RoachMetricRow {
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
                                .font(RoachType.caption)
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
                    detail: model.runtime?.roachClaw.error ?? "Model selection, installed packs, and provider state all show here without leaving the phone."
                )

                RoachMetricRow {
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
                            .font(RoachType.headline())
                            .foregroundStyle(RoachTheme.text)

                        ForEach(installedModels.prefix(6)) { model in
                            HStack {
                                Text(model.name)
                                    .font(RoachType.mono(12, relativeTo: .caption))
                                    .foregroundStyle(RoachTheme.text)
                                Spacer()
                                Text(formattedBytes(model.size))
                                    .font(RoachType.caption2)
                                    .foregroundStyle(RoachTheme.subduedText)
                            }
                        }
                    }
                }

                if let lanes = model.runtime?.roachClaw.playbook?.lanes, !lanes.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        RoachSectionHeader(
                            eyebrow: "Playbook",
                            title: "Cookbook, research, compare.",
                            detail: "RoachClaw-native moves for model fit, research, blind comparison, and RoachBrain cleanup."
                        )

                        if let capabilities = model.runtime?.roachClaw.playbook?.capabilities, !capabilities.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(capabilities.prefix(6), id: \.self) { capability in
                                        RoachStatusPill(
                                            title: playbookCapabilityLabel(capability),
                                            accent: capability.contains("voice") ? RoachTheme.tertiary : RoachTheme.secondary
                                        )
                                    }
                                }
                                .padding(.horizontal, 1)
                            }
                        }

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(minimum: 0), spacing: 10),
                                GridItem(.flexible(minimum: 0), spacing: 10),
                            ],
                            alignment: .leading,
                            spacing: 10
                        ) {
                            ForEach(lanes.prefix(4)) { lane in
                                RoachSignalTile(
                                    label: lane.title,
                                    value: playbookStatusLabel(lane.status),
                                    accent: playbookAccent(lane.accent),
                                    systemImage: playbookIcon(lane.icon)
                                )
                                .accessibilityLabel("\(lane.title), \(playbookStatusLabel(lane.status)). \(lane.summary)")
                            }
                        }
                    }
                }

                if let featureGroups = model.runtime?.roachClaw.playbook?.featureGroups, !featureGroups.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        RoachSectionHeader(
                            eyebrow: "Native map",
                            title: "Every lane gets a RoachNet surface.",
                            detail: "Chat, agents, docs, memory, mail, calendar, media, voice, security, and iOS stay tracked as native work."
                        )

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(minimum: 0), spacing: 10),
                                GridItem(.flexible(minimum: 0), spacing: 10),
                            ],
                            alignment: .leading,
                            spacing: 10
                        ) {
                            ForEach(featureGroups) { feature in
                                RoachSignalTile(
                                    label: feature.title,
                                    value: playbookStatusLabel(feature.status),
                                    accent: featureGroupAccent(feature),
                                    systemImage: featureGroupIcon(feature.id)
                                )
                                .accessibilityLabel("\(feature.title), \(playbookStatusLabel(feature.status)). \(feature.summary)")
                            }
                        }
                    }
                }

                if let operations = model.runtime?.roachClaw.operations {
                    VStack(alignment: .leading, spacing: 10) {
                        RoachSectionHeader(
                            eyebrow: "Ops",
                            title: "The useful wires are visible.",
                            detail: "Diagnostics, hooks, jobs, contacts, reports, and recovery state stay local and inspectable."
                        )

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(minimum: 0), spacing: 10),
                                GridItem(.flexible(minimum: 0), spacing: 10),
                            ],
                            alignment: .leading,
                            spacing: 10
                        ) {
                            if let commandDeck = operations.commandDeck {
                                RoachSignalTile(
                                    label: "Command",
                                    value: "\(commandDeck.count ?? 0) actions",
                                    accent: RoachTheme.tertiary,
                                    systemImage: "command.circle",
                                    subtitle: shellSurfaceSubtitle(commandDeck)
                                )
                            }

                            if let contextRail = operations.contextRail {
                                RoachSignalTile(
                                    label: "Context",
                                    value: "\(contextRail.count ?? 0) crumbs",
                                    accent: RoachTheme.secondary,
                                    systemImage: "sidebar.trailing",
                                    subtitle: shellSurfaceSubtitle(contextRail)
                                )
                            }

                            if let vaultNavigator = operations.vaultNavigator {
                                RoachSignalTile(
                                    label: "Vault",
                                    value: "\(vaultNavigator.count ?? 0) local",
                                    accent: RoachTheme.primary,
                                    systemImage: "folder.badge.gearshape",
                                    subtitle: shellSurfaceSubtitle(vaultNavigator)
                                )
                            }

                            if let agentMonitor = operations.agentMonitor {
                                RoachSignalTile(
                                    label: "Monitor",
                                    value: "\(agentMonitor.active ?? 0) live",
                                    accent: (agentMonitor.stalled ?? 0) > 0 ? .orange : RoachTheme.primary,
                                    systemImage: "waveform.path.ecg.rectangle",
                                    subtitle: shellSurfaceSubtitle(agentMonitor)
                                )
                            }

                            if let orchestration = operations.orchestrationDashboard {
                                RoachSignalTile(
                                    label: "Orchestration",
                                    value: "\(orchestration.open ?? 0) handoffs",
                                    accent: RoachTheme.tertiary,
                                    systemImage: "rectangle.3.group",
                                    subtitle: shellSurfaceSubtitle(orchestration)
                                )
                            }
                        }

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(minimum: 0), spacing: 10),
                                GridItem(.flexible(minimum: 0), spacing: 10),
                            ],
                            alignment: .leading,
                            spacing: 10
                        ) {
                            if let diagnostics = operations.diagnostics {
                                RoachSignalTile(
                                    label: "Diagnostics",
                                    value: playbookStatusLabel(diagnostics.status),
                                    accent: diagnostics.warnings?.isEmpty == false ? .orange : RoachTheme.secondary,
                                    systemImage: "stethoscope"
                                )
                            }

                            if let serviceHealth = operations.serviceHealth {
                                RoachSignalTile(
                                    label: "Service Health",
                                    value: playbookStatusLabel(serviceHealth.status),
                                    accent: serviceHealth.status == "ok" ? RoachTheme.secondary : .orange,
                                    systemImage: "waveform.path.ecg.rectangle"
                                )
                            }

                            if let hooks = operations.hooks {
                                RoachSignalTile(
                                    label: "Hooks",
                                    value: playbookStatusLabel(hooks.status),
                                    accent: RoachTheme.tertiary,
                                    systemImage: "point.3.connected.trianglepath.dotted"
                                )
                            }

                            if let jobs = operations.jobs {
                                RoachSignalTile(
                                    label: "Jobs",
                                    value: "\(jobs.scheduler.pending) queued",
                                    accent: jobs.status == "idle" ? RoachTheme.subduedText : RoachTheme.secondary,
                                    systemImage: "clock.arrow.circlepath"
                                )
                            }

                            if let contacts = operations.contacts {
                                RoachSignalTile(
                                    label: "Contacts",
                                    value: "\(contacts.recordCount ?? 0) local",
                                    accent: RoachTheme.tertiary,
                                    systemImage: "person.2.wave.2"
                                )
                            }

                            if let tasks = operations.notesTasks {
                                RoachSignalTile(
                                    label: "Tasks",
                                    value: "\(tasks.open ?? tasks.count ?? 0) open",
                                    accent: RoachTheme.secondary,
                                    systemImage: "checklist"
                                )
                            }

                            if let calendar = operations.calendar {
                                RoachSignalTile(
                                    label: "Calendar",
                                    value: "\(calendar.count ?? 0) events",
                                    accent: .orange,
                                    systemImage: "calendar.badge.clock"
                                )
                            }

                            if let reports = operations.reports {
                                RoachSignalTile(
                                    label: "Reports",
                                    value: "\(reports.count ?? 0) saved",
                                    accent: RoachTheme.secondary,
                                    systemImage: "chart.bar.doc.horizontal"
                                )
                            }

                            if let memories = operations.memories {
                                RoachSignalTile(
                                    label: "Memories",
                                    value: "\(memories.count ?? 0) saved",
                                    accent: .orange,
                                    systemImage: "brain.head.profile"
                                )
                            }

                            if let skills = operations.skills {
                                RoachSignalTile(
                                    label: "Skills",
                                    value: "\(skills.count ?? 0) ready",
                                    accent: RoachTheme.primary,
                                    systemImage: "sparkles.square.filled.on.square"
                                )
                            }

                            if let drafts = operations.editorDrafts {
                                RoachSignalTile(
                                    label: "Drafts",
                                    value: "\(drafts.open ?? drafts.count ?? 0) open",
                                    accent: RoachTheme.tertiary,
                                    systemImage: "doc.text"
                                )
                            }

                            if let migrationTools = operations.migrationDocumentTools {
                                RoachSignalTile(
                                    label: "Migration",
                                    value: playbookStatusLabel(migrationTools.status),
                                    accent: RoachTheme.tertiary,
                                    systemImage: "doc.badge.gearshape",
                                    subtitle: shellSurfaceSubtitle(migrationTools)
                                )
                            }

                            if let searchCache = operations.searchCache {
                                RoachSignalTile(
                                    label: "Search",
                                    value: "\(searchCache.count ?? 0) cached",
                                    accent: RoachTheme.secondary,
                                    systemImage: "magnifyingglass.circle"
                                )
                            }

                            if let gallery = operations.gallery {
                                RoachSignalTile(
                                    label: "Gallery",
                                    value: "\(gallery.count ?? 0) assets",
                                    accent: RoachTheme.primary,
                                    systemImage: "photo.on.rectangle.angled"
                                )
                            }

                            if let webhooks = operations.webhooks {
                                RoachSignalTile(
                                    label: "Hooks",
                                    value: "\(webhooks.active ?? 0) armed",
                                    accent: RoachTheme.secondary,
                                    systemImage: "point.3.connected.trianglepath.dotted"
                                )
                            }

                            if let runs = operations.agentRuns {
                                RoachSignalTile(
                                    label: "Runs",
                                    value: "\(runs.active ?? 0) live",
                                    accent: RoachTheme.primary,
                                    systemImage: "bolt.badge.clock"
                                )
                            }

                            if let compactions = operations.contextCompactions {
                                RoachSignalTile(
                                    label: "Context",
                                    value: "\(compactions.count ?? 0) saved",
                                    accent: .orange,
                                    systemImage: "text.badge.checkmark"
                                )
                            }

                            if let toolIndex = operations.toolIndex {
                                RoachSignalTile(
                                    label: "Tools",
                                    value: "\(toolIndex.active ?? toolIndex.count ?? 0) armed",
                                    accent: RoachTheme.tertiary,
                                    systemImage: "wrench.and.screwdriver"
                                )
                            }

                            if let embeddingLanes = operations.embeddingLanes {
                                RoachSignalTile(
                                    label: "Embeddings",
                                    value: "\(embeddingLanes.active ?? embeddingLanes.count ?? 0) active",
                                    accent: embeddingLanes.status == "healthy" ? RoachTheme.primary : .orange,
                                    systemImage: "point.3.filled.connected.trianglepath.dotted",
                                    subtitle: shellSurfaceSubtitle(embeddingLanes)
                                )
                            }

                            if let toolPolicy = operations.toolPolicy {
                                RoachSignalTile(
                                    label: "Policy",
                                    value: playbookStatusLabel(toolPolicy.status),
                                    accent: toolPolicy.status == "guide-only" ? .orange : RoachTheme.secondary,
                                    systemImage: "shield.lefthalf.filled",
                                    subtitle: shellSurfaceSubtitle(toolPolicy)
                                )
                            }

                            if let uploadLimits = operations.uploadLimits {
                                RoachSignalTile(
                                    label: "Intake",
                                    value: playbookStatusLabel(uploadLimits.status),
                                    accent: RoachTheme.primary,
                                    systemImage: "tray.and.arrow.down.fill",
                                    subtitle: shellSurfaceSubtitle(uploadLimits)
                                )
                            }

                            if let events = operations.events {
                                RoachSignalTile(
                                    label: "Events",
                                    value: "\(events.count ?? 0) counters",
                                    accent: RoachTheme.secondary,
                                    systemImage: "dot.radiowaves.left.and.right"
                                )
                            }

                            if let mail = operations.mail {
                                RoachSignalTile(
                                    label: "RoachMail",
                                    value: "\(mail.messages ?? 0) / \(mail.drafts ?? 0)",
                                    accent: RoachTheme.tertiary,
                                    systemImage: "envelope.badge"
                                )
                            }

                            if let presets = operations.presets {
                                RoachSignalTile(
                                    label: "Presets",
                                    value: "\(presets.count ?? 0) saved",
                                    accent: RoachTheme.secondary,
                                    systemImage: "slider.horizontal.3"
                                )
                            }

                            if let signatures = operations.signatures {
                                RoachSignalTile(
                                    label: "Signatures",
                                    value: "\(signatures.count ?? 0) saved",
                                    accent: .orange,
                                    systemImage: "signature"
                                )
                            }

                            if let tokens = operations.apiTokens {
                                RoachSignalTile(
                                    label: "Tokens",
                                    value: "\(tokens.active ?? 0) active",
                                    accent: RoachTheme.primary,
                                    systemImage: "key.horizontal"
                                )
                            }

                            if let backups = operations.backups {
                                RoachSignalTile(
                                    label: "Backups",
                                    value: "\(backups.count ?? 0) snaps",
                                    accent: RoachTheme.tertiary,
                                    systemImage: "externaldrive.badge.timemachine"
                                )
                            }
                        }
                    }
                }

                if let referenceInventory = model.runtime?.roachClaw.playbook?.referenceInventory {
                    VStack(alignment: .leading, spacing: 10) {
                        RoachSectionHeader(
                            eyebrow: "GitHub upstream",
                            title: "\(referenceInventory.functionalFileCount) functional files tracked.",
                            detail: "\(referenceInventory.observedFileCount) files observed. The reference stack stays reference-only while RoachNet owns native rewrites."
                        )

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(minimum: 0), spacing: 10),
                                GridItem(.flexible(minimum: 0), spacing: 10),
                            ],
                            alignment: .leading,
                            spacing: 10
                        ) {
                            ForEach(referenceInventory.coverageGroups.prefix(8)) { group in
                                RoachSignalTile(
                                    label: group.label,
                                    value: "\(group.fileCount) files",
                                    accent: RoachTheme.secondary,
                                    systemImage: inventoryGroupIcon(group.id)
                                )
                                .accessibilityLabel("\(group.label), \(group.fileCount) files, \(group.nativeSurface)")
                            }
                        }
                    }
                }

                if let referenceModules = model.runtime?.roachClaw.playbook?.referenceModules, !referenceModules.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        RoachSectionHeader(
                            eyebrow: "Coverage",
                            title: "\(referenceModules.count) modules tracked.",
                            detail: "The reference surface is mapped into RoachNet-native owners instead of being left as a mystery pile."
                        )

                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(minimum: 0), spacing: 10),
                                GridItem(.flexible(minimum: 0), spacing: 10),
                            ],
                            alignment: .leading,
                            spacing: 10
                        ) {
                            ForEach(referenceModules.prefix(8)) { module in
                                RoachSignalTile(
                                    label: moduleName(module.source),
                                    value: module.nativeSurface,
                                    accent: module.status.contains("planned") ? .orange : RoachTheme.secondary,
                                    systemImage: moduleIcon(module.category)
                                )
                                .accessibilityLabel("\(module.source), \(module.nativeSurface), \(playbookStatusLabel(module.status))")
                            }
                        }
                    }
                }
            }
        }
    }

    private func playbookCapabilityLabel(_ capability: String) -> String {
        switch capability {
        case "roachclaw-cookbook":
            return "Cookbook"
        case "roachclaw-quant-aware-fit":
            return "Quant Fit"
        case "roachclaw-deep-research":
            return "Research"
        case "roachclaw-model-compare":
            return "Compare"
        case "roachclaw-assistant-crew":
            return "Assistant Crew"
        case "roachclaw-session-history":
            return "Session History"
        case "roachclaw-provider-routes":
            return "Provider Routes"
        case "roachclaw-backup-restore":
            return "Backup"
        case "roachclaw-signatures":
            return "Signatures"
        case "roachclaw-local-api-keys":
            return "Local Keys"
        case "roachclaw-font-emoji-assets":
            return "Assets"
        case "roachclaw-housekeeping":
            return "Housekeeping"
        case "roachclaw-upload-limits":
            return "Intake Policy"
        case "roachbrain-memory-skills-audit":
            return "RoachBrain"
        case "vault-document-assist":
            return "Vault Docs"
        case "roachspeech-voice-lane":
            return "Voice"
        default:
            return capability
                .replacingOccurrences(of: "roachclaw-", with: "")
                .replacingOccurrences(of: "roachbrain-", with: "")
                .replacingOccurrences(of: "-", with: " ")
                .capitalized
        }
    }

    private func playbookStatusLabel(_ status: String) -> String {
        status
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { $0.prefix(1).uppercased() + String($0.dropFirst()) }
            .joined(separator: " ")
    }

    private func shellSurfaceSubtitle(_ lane: CompanionRoachClawOperations.CollectionLane) -> String? {
        var parts: [String] = []

        if let priority = lane.priority, !priority.isEmpty {
            parts.append(playbookStatusLabel(priority))
        }

        if let hotkey = lane.hotkey, !hotkey.isEmpty {
            parts.append(hotkey)
        }

        if let firstSummary = lane.summaryItems?.first, !firstSummary.isEmpty {
            parts.append(firstSummary)
        }

        return parts.isEmpty ? nil : parts.prefix(3).joined(separator: " · ")
    }

    private func playbookIcon(_ icon: String?) -> String {
        switch icon {
        case "rectangle.stack.badge.person.crop":
            return "rectangle.stack.badge.person.crop"
        case "slider.horizontal.below.rectangle":
            return "slider.horizontal.below.rectangle"
        case "cpu":
            return "cpu.fill"
        case "doc.text.magnifyingglass":
            return "doc.text.magnifyingglass"
        case "rectangle.split.2x1":
            return "rectangle.split.2x1.fill"
        case "brain.head.profile":
            return "brain.head.profile"
        case "doc.richtext":
            return "doc.richtext.fill"
        case "doc.badge.gearshape":
            return "doc.badge.gearshape"
        case "waveform":
            return "waveform"
        case "paintpalette":
            return "paintpalette.fill"
        case "stethoscope":
            return "wrench.and.screwdriver.fill"
        case "person.2.wave.2":
            return "person.2.fill"
        case "chart.bar.doc.horizontal":
            return "chart.bar.fill"
        case "person.3.sequence":
            return "person.3.sequence.fill"
        case "externaldrive.badge.timemachine":
            return "externaldrive.badge.timemachine"
        case "rectangle.3.group":
            return "rectangle.3.group.fill"
        case "bolt.badge.clock":
            return "bolt.badge.clock.fill"
        case "waveform.path.ecg.rectangle":
            return "waveform.path.ecg.rectangle"
        default:
            return "sparkles"
        }
    }

    private func featureGroupIcon(_ id: String) -> String {
        switch id {
        case "chat":
            return "bubble.left.and.bubble.right.fill"
        case "session-board":
            return "rectangle.stack.badge.person.crop.fill"
        case "agent-tools":
            return "hammer.fill"
        case "cookbook":
            return "cpu.fill"
        case "deep-research":
            return "doc.text.magnifyingglass"
        case "compare":
            return "rectangle.split.2x1.fill"
        case "model-bench":
            return "slider.horizontal.below.rectangle"
        case "documents":
            return "doc.richtext.fill"
        case "memory-skills":
            return "brain.head.profile"
        case "email":
            return "envelope.fill"
        case "notes-tasks":
            return "checklist"
        case "calendar":
            return "calendar"
        case "search-rag":
            return "magnifyingglass.circle.fill"
        case "voice":
            return "waveform"
        case "gallery-editor":
            return "photo.on.rectangle"
        case "security":
            return "lock.shield.fill"
        case "mobile":
            return "iphone"
        case "contacts":
            return "person.crop.circle.badge.checkmark"
        case "diagnostics":
            return "wrench.and.screwdriver.fill"
        case "preferences":
            return "slider.horizontal.3"
        case "session-history":
            return "clock.arrow.circlepath"
        case "model-providers":
            return "network"
        case "assistant-crew":
            return "person.3.sequence.fill"
        case "orchestration":
            return "rectangle.3.group.fill"
        case "signatures":
            return "signature"
        case "backup-restore":
            return "externaldrive.badge.timemachine"
        case "local-api-keys":
            return "key.horizontal.fill"
        case "font-emoji-assets":
            return "textformat.alt"
        case "housekeeping":
            return "sparkles.rectangle.stack.fill"
        case "theme-studio":
            return "paintpalette.fill"
        case "uploads-personal-docs":
            return "tray.and.arrow.down.fill"
        case "webhooks-integrations":
            return "point.3.connected.trianglepath.dotted"
        case "background-jobs":
            return "clock.arrow.circlepath"
        case "visual-reports":
            return "chart.bar.doc.horizontal"
        case "admin-recovery":
            return "lock.rotation"
        default:
            return "square.grid.2x2.fill"
        }
    }

    private func featureGroupAccent(_ feature: CompanionRoachClawFeatureGroup) -> Color {
        if feature.status.contains("planned") {
            return .orange
        }
        if feature.status.contains("warmup") || feature.status.contains("needs") {
            return RoachTheme.primary
        }
        if feature.id == "voice" || feature.id == "search-rag" || feature.id == "calendar" {
            return RoachTheme.tertiary
        }
        return RoachTheme.secondary
    }

    private func moduleName(_ source: String) -> String {
        source.split(separator: "/").last.map(String.init) ?? source
    }

    private func moduleIcon(_ category: String) -> String {
        switch category {
        case "route":
            return "arrow.triangle.branch"
        case "web":
            return "globe"
        case "source":
            return "curlybraces"
        default:
            return "shippingbox.fill"
        }
    }

    private func inventoryGroupIcon(_ id: String) -> String {
        switch id {
        case "routes":
            return "arrow.triangle.branch"
        case "core":
            return "cpu.fill"
        case "source":
            return "curlybraces"
        case "services":
            return "server.rack"
        case "mcp-servers":
            return "point.3.connected.trianglepath.dotted"
        case "scripts":
            return "terminal.fill"
        case "companion":
            return "iphone.gen3"
        case "static-js":
            return "rectangle.3.group.bubble.left"
        default:
            return "square.stack.3d.up.fill"
        }
    }

    private func playbookAccent(_ accent: String?) -> Color {
        switch accent {
        case "cyan":
            return RoachTheme.tertiary
        case "magenta":
            return RoachTheme.primary
        case "bronze":
            return .orange
        default:
            return RoachTheme.secondary
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
                                .font(RoachType.mono(12, relativeTo: .caption))
                                .foregroundStyle(RoachTheme.text)
                                .lineLimit(1)

                            HStack {
                                Text(job.status ?? "Queued")
                                    .font(RoachType.caption)
                                    .foregroundStyle(RoachTheme.subduedText)
                                Spacer()
                                Text(job.progress.map { "\($0)%" } ?? "--")
                                    .font(RoachType.caption)
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
                                .font(RoachType.mono(12, relativeTo: .caption))
                                .foregroundStyle(RoachTheme.secondary)
                            Text(issue.error)
                                .font(RoachType.caption)
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
                        .font(RoachType.subheadline(.semibold))
                        .foregroundStyle(RoachTheme.text)

                    Text(service.status ?? "Unknown state")
                        .font(RoachType.caption)
                        .foregroundStyle(RoachTheme.subduedText)
                }

                Spacer()

                RoachBadge(
                    title: (service.installed ?? false) ? "Installed" : "Optional",
                    accent: (service.installed ?? false) ? RoachTheme.secondary : RoachTheme.tertiary
                )
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    runtimeActionButton(title: "Start", service: service.serviceName, action: "start")
                    runtimeActionButton(title: "Restart", service: service.serviceName, action: "restart")
                    runtimeActionButton(title: "Stop", service: service.serviceName, action: "stop")
                }

                VStack(spacing: 8) {
                    runtimeActionButton(title: "Start", service: service.serviceName, action: "start")
                    runtimeActionButton(title: "Restart", service: service.serviceName, action: "restart")
                    runtimeActionButton(title: "Stop", service: service.serviceName, action: "stop")
                }
            }
        }
    }

    private func runtimeActionButton(title: String, service: String, action: String) -> some View {
        Button(title) {
            Task {
                await model.affectService(service, action: action)
            }
        }
        .buttonStyle(RoachButtonStyle(kind: .secondary, size: .compact))
        .tint(action == "stop" ? RoachTheme.primary : RoachTheme.secondary)
        .disabled(model.actingServiceNames.contains(service))
        .frame(maxWidth: .infinity)
    }

    private func roachTailToggle(_ roachTail: CompanionRoachTailStatus) -> some View {
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
                    .font(RoachType.subheadline(.semibold))
                    .foregroundStyle(RoachTheme.text)
                Text(roachTail.enabled ? "Private overlay is armed." : "Private overlay is off.")
                    .font(RoachType.caption)
                    .foregroundStyle(RoachTheme.subduedText)
            }
        }
        .toggleStyle(.switch)
        .tint(RoachTheme.secondary)
        .disabled(model.isActingRoachTail)
    }
}

enum RoachPhoneGPSAdvertiserState: Equatable {
    case idle
    case requestingLocation
    case waitingForBluetooth
    case advertising
    case streaming(Int)
    case bluetoothOff
    case bluetoothDenied
    case bluetoothUnsupported
    case locationDenied
    case failed(String)

    var label: String {
        switch self {
        case .idle:
            return "Off"
        case .requestingLocation:
            return "Location"
        case .waitingForBluetooth:
            return "Bluetooth"
        case .advertising:
            return "Advertising"
        case let .streaming(count):
            return count == 1 ? "1 Mac" : "\(count) Macs"
        case .bluetoothOff:
            return "BT off"
        case .bluetoothDenied:
            return "BT blocked"
        case .bluetoothUnsupported:
            return "No BLE"
        case .locationDenied:
            return "Location off"
        case .failed:
            return "Retry"
        }
    }

    var detail: String {
        switch self {
        case .idle:
            return "Ready to advertise a RoachAtlas GPS packet when you start it."
        case .requestingLocation:
            return "Waiting for foreground location permission."
        case .waitingForBluetooth:
            return "Waiting for Bluetooth to become available."
        case .advertising:
            return "RoachPhone GPS is visible to the desktop RoachAtlas receiver."
        case let .streaming(count):
            return count == 1 ? "One desktop receiver subscribed." : "\(count) desktop receivers subscribed."
        case .bluetoothOff:
            return "Turn on Bluetooth to advertise the GPS bridge."
        case .bluetoothDenied:
            return "Allow Bluetooth access for RoachNetiOS."
        case .bluetoothUnsupported:
            return "This device cannot act as the RoachAtlas BLE GPS source."
        case .locationDenied:
            return "Allow Location access while using RoachNetiOS."
        case let .failed(message):
            return message
        }
    }

    var accent: Color {
        switch self {
        case .advertising, .streaming:
            return RoachTheme.secondary
        case .requestingLocation, .waitingForBluetooth:
            return RoachTheme.tertiary
        case .idle:
            return RoachTheme.primary
        default:
            return RoachTheme.primary
        }
    }
}

struct RoachPhoneGPSFix: Equatable {
    let latitude: Double
    let longitude: Double
    let accuracyMeters: Double?
    let speedMetersPerSecond: Double?
    let courseDegrees: Double?
    let altitudeMeters: Double?
    let timestamp: Date

    var coordinateLabel: String {
        String(format: "%.5f, %.5f", latitude, longitude)
    }

    var accuracyLabel: String {
        guard let accuracyMeters else { return "unknown" }
        return accuracyMeters >= 1_609.344
            ? String(format: "%.1f mi", accuracyMeters / 1_609.344)
            : String(format: "%.0f m", accuracyMeters)
    }

    var speedLabel: String {
        guard let speedMetersPerSecond, speedMetersPerSecond >= 0 else { return "idle" }
        return String(format: "%.0f mph", speedMetersPerSecond * 2.2369362921)
    }

    var headingLabel: String {
        guard let courseDegrees, courseDegrees >= 0 else { return "no heading" }
        return "\(Int(courseDegrees.rounded())) deg"
    }

    var ageLabel: String {
        formattedRelativeDate(timestamp)
    }
}

final class RoachPhoneGPSAdvertiser: NSObject, ObservableObject {
    static let gpsServiceUUIDString = "E4B29778-2F25-4C70-9B4A-0F9D1D481105"
    static let gpsCharacteristicUUIDString = "E4B29779-2F25-4C70-9B4A-0F9D1D481105"
    private static let gpsServiceUUID = CBUUID(string: gpsServiceUUIDString)
    private static let gpsCharacteristicUUID = CBUUID(string: gpsCharacteristicUUIDString)

    @Published var highAccuracy = true {
        didSet { applyLocationConfiguration() }
    }
    @Published var includeMotionDetails = true {
        didSet {
            if let lastLocation {
                publish(location: lastLocation)
            }
        }
    }
    @Published private(set) var state: RoachPhoneGPSAdvertiserState = .idle
    @Published private(set) var latestFix: RoachPhoneGPSFix?
    @Published private(set) var lastPacket: String?
    @Published private(set) var packetCount = 0

    private let locationManager = CLLocationManager()
    private var peripheralManager: CBPeripheralManager?
    private var gpsCharacteristic: CBMutableCharacteristic?
    private var pendingNotifyData: Data?
    private var subscribedCentralCount = 0
    private var lastLocation: CLLocation?
    private var wantsBridgeRunning = false

    var isRunning: Bool {
        switch state {
        case .requestingLocation, .waitingForBluetooth, .advertising, .streaming:
            return wantsBridgeRunning
        default:
            return false
        }
    }

    override init() {
        super.init()
        locationManager.delegate = self
        applyLocationConfiguration()
    }

    func start() {
        wantsBridgeRunning = true
        state = .requestingLocation

        guard CLLocationManager.locationServicesEnabled() else {
            state = .locationDenied
            return
        }

        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            startLocationAndBluetooth()
        case .denied, .restricted:
            state = .locationDenied
        @unknown default:
            state = .failed("Unknown Location permission state.")
        }
    }

    func stop() {
        wantsBridgeRunning = false
        locationManager.stopUpdatingLocation()
        peripheralManager?.stopAdvertising()
        peripheralManager?.removeAllServices()
        gpsCharacteristic = nil
        pendingNotifyData = nil
        subscribedCentralCount = 0
        state = .idle
    }

    func publishDemoFix() {
        let index = Double(packetCount % 8)
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(
                latitude: 39.76862 + index * 0.00032,
                longitude: -86.15823 - index * 0.00029
            ),
            altitude: 218 + index,
            horizontalAccuracy: 8 + index,
            verticalAccuracy: 12,
            course: 244 + index * 3,
            speed: 10.4 + index,
            timestamp: Date()
        )
        publish(location: location)
    }

    private func startLocationAndBluetooth() {
        guard wantsBridgeRunning else { return }
        applyLocationConfiguration()
        locationManager.startUpdatingLocation()

        if peripheralManager == nil {
            state = .waitingForBluetooth
            peripheralManager = CBPeripheralManager(delegate: self, queue: .main)
        } else {
            configurePeripheralIfPossible()
        }
    }

    private func applyLocationConfiguration() {
        locationManager.desiredAccuracy = highAccuracy ? kCLLocationAccuracyBest : kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = highAccuracy ? 5 : 25
        locationManager.pausesLocationUpdatesAutomatically = true
        locationManager.allowsBackgroundLocationUpdates = false
    }

    private func configurePeripheralIfPossible() {
        guard wantsBridgeRunning, let peripheralManager else { return }

        switch peripheralManager.state {
        case .poweredOn:
            let characteristic = CBMutableCharacteristic(
                type: Self.gpsCharacteristicUUID,
                properties: [.read, .notify],
                value: nil,
                permissions: [.readable]
            )
            let service = CBMutableService(type: Self.gpsServiceUUID, primary: true)
            service.characteristics = [characteristic]
            gpsCharacteristic = characteristic
            peripheralManager.removeAllServices()
            peripheralManager.add(service)
            state = .waitingForBluetooth
        case .poweredOff:
            state = .bluetoothOff
        case .unauthorized:
            state = .bluetoothDenied
        case .unsupported:
            state = .bluetoothUnsupported
        case .resetting, .unknown:
            state = .waitingForBluetooth
        @unknown default:
            state = .failed("Unknown Bluetooth state.")
        }
    }

    private func startAdvertising() {
        guard wantsBridgeRunning, let peripheralManager else { return }

        peripheralManager.stopAdvertising()
        peripheralManager.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [Self.gpsServiceUUID],
            CBAdvertisementDataLocalNameKey: "RoachPhone GPS",
        ])
    }

    private func publish(location: CLLocation) {
        lastLocation = location

        guard CLLocationCoordinate2DIsValid(location.coordinate) else {
            state = .failed("The current location fix is invalid.")
            return
        }

        let fix = RoachPhoneGPSFix(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            accuracyMeters: location.horizontalAccuracy >= 0 ? location.horizontalAccuracy : nil,
            speedMetersPerSecond: includeMotionDetails && location.speed >= 0 ? location.speed : nil,
            courseDegrees: includeMotionDetails && location.course >= 0 ? normalizedCourse(location.course) : nil,
            altitudeMeters: includeMotionDetails && location.verticalAccuracy >= 0 ? location.altitude : nil,
            timestamp: location.timestamp
        )
        latestFix = fix

        guard let packet = makePacket(from: fix), let data = packet.data(using: .utf8) else {
            state = .failed("RoachAtlas could not encode the GPS packet.")
            return
        }

        guard packet.count <= 4_096 else {
            state = .failed("RoachAtlas GPS packet exceeded the desktop bridge limit.")
            return
        }

        lastPacket = packet
        packetCount += 1

        guard subscribedCentralCount > 0, let gpsCharacteristic else { return }
        let accepted = peripheralManager?.updateValue(data, for: gpsCharacteristic, onSubscribedCentrals: nil) ?? false
        if !accepted {
            pendingNotifyData = data
        }
    }

    private func makePacket(from fix: RoachPhoneGPSFix) -> String? {
        var payload: [String: Any] = [
            "lat": fix.latitude,
            "lon": fix.longitude,
            "timestamp": Self.isoTimestamp(fix.timestamp),
            "source": "RoachPhone",
        ]

        if let accuracyMeters = fix.accuracyMeters {
            payload["accuracy"] = accuracyMeters
        }
        if let speedMetersPerSecond = fix.speedMetersPerSecond {
            payload["speed"] = speedMetersPerSecond
        }
        if let courseDegrees = fix.courseDegrees {
            payload["course"] = courseDegrees
        }
        if let altitudeMeters = fix.altitudeMeters {
            payload["altitude"] = altitudeMeters
        }

        guard
            JSONSerialization.isValidJSONObject(payload),
            let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private func updateStreamingState() {
        guard wantsBridgeRunning else { return }
        state = subscribedCentralCount > 0 ? .streaming(subscribedCentralCount) : .advertising
    }

    private func normalizedCourse(_ value: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: 360)
        return remainder < 0 ? remainder + 360 : remainder
    }

    private static func isoTimestamp(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }
}

extension RoachPhoneGPSAdvertiser: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard wantsBridgeRunning else { return }

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            startLocationAndBluetooth()
        case .notDetermined:
            state = .requestingLocation
        case .denied, .restricted:
            state = .locationDenied
        @unknown default:
            state = .failed("Unknown Location permission state.")
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard wantsBridgeRunning, let location = locations.last else { return }
        publish(location: location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard wantsBridgeRunning else { return }
        state = .failed(error.localizedDescription)
    }
}

extension RoachPhoneGPSAdvertiser: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        configurePeripheralIfPossible()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error {
            state = .failed(error.localizedDescription)
            return
        }
        startAdvertising()
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error {
            state = .failed(error.localizedDescription)
            return
        }
        updateStreamingState()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        guard characteristic.uuid == Self.gpsCharacteristicUUID else { return }
        subscribedCentralCount += 1
        updateStreamingState()

        if let lastPacket, let data = lastPacket.data(using: .utf8), let gpsCharacteristic {
            let accepted = peripheral.updateValue(data, for: gpsCharacteristic, onSubscribedCentrals: [central])
            if !accepted {
                pendingNotifyData = data
            }
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        guard characteristic.uuid == Self.gpsCharacteristicUUID else { return }
        subscribedCentralCount = max(0, subscribedCentralCount - 1)
        updateStreamingState()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        guard request.characteristic.uuid == Self.gpsCharacteristicUUID else {
            peripheral.respond(to: request, withResult: .attributeNotFound)
            return
        }

        guard let data = lastPacket?.data(using: .utf8) else {
            request.value = Data()
            peripheral.respond(to: request, withResult: .success)
            return
        }

        guard request.offset <= data.count else {
            peripheral.respond(to: request, withResult: .invalidOffset)
            return
        }

        request.value = data.subdata(in: request.offset..<data.count)
        peripheral.respond(to: request, withResult: .success)
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        guard let pendingNotifyData, let gpsCharacteristic else { return }
        let accepted = peripheral.updateValue(pendingNotifyData, for: gpsCharacteristic, onSubscribedCentrals: nil)
        if accepted {
            self.pendingNotifyData = nil
        }
    }
}
