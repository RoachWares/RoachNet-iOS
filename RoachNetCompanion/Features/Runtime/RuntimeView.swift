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
                        value: model.connection.isConfigured ? "Loaded" : "Missing",
                        accent: model.connection.isConfigured ? RoachTheme.secondary : RoachTheme.primary
                    )
                }

                if model.pairedMachineName != nil {
                    Text("Paired desktop linked.")
                        .font(.caption)
                        .foregroundStyle(RoachTheme.subduedText)
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
