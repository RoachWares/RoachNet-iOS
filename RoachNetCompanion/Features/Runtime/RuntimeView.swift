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
                        runtimePanel
                        roachClawPanel
                        servicesPanel
                        downloadsPanel
                        issuesPanel
                    }
                    .padding(16)
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
            VStack(alignment: .leading, spacing: 10) {
                Text("Companion lane")
                    .font(.headline)
                    .foregroundStyle(RoachTheme.text)

                Text(model.connection.baseURL)
                    .font(.subheadline.monospaced())
                    .foregroundStyle(RoachTheme.text)

                Text(model.connection.isConfigured ? "Token loaded." : "Still needs a companion token.")
                    .font(.caption)
                    .foregroundStyle(RoachTheme.subduedText)

                if let pairedMachineName = model.pairedMachineName {
                    Text(pairedMachineName)
                        .font(.caption.monospaced())
                        .foregroundStyle(RoachTheme.secondary)
                }

                if let hostname = model.runtime?.systemInfo?.os?.hostname {
                    Text(hostname)
                        .font(.caption.monospaced())
                        .foregroundStyle(RoachTheme.secondary)
                }
            }
        }
    }

    private var runtimePanel: some View {
        RoachPanel {
            VStack(alignment: .leading, spacing: 10) {
                Text("Machine")
                    .font(.headline)
                    .foregroundStyle(RoachTheme.text)

                Text(model.runtime?.systemInfo?.hardwareProfile?.platformLabel ?? "RoachNet desktop")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(RoachTheme.text)

                Text(model.runtime?.systemInfo?.hardwareProfile?.recommendedModelClass ?? "Model guidance unavailable.")
                    .font(.subheadline)
                    .foregroundStyle(RoachTheme.subduedText)

                if let available = model.runtime?.systemInfo?.mem?.available {
                    Text("Available memory: \(formattedBytes(Int64(available)))")
                        .font(.caption)
                        .foregroundStyle(RoachTheme.secondary)
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
            VStack(alignment: .leading, spacing: 10) {
                Text("RoachClaw")
                    .font(.headline)
                    .foregroundStyle(RoachTheme.text)

                HStack {
                    RoachBadge(
                        title: (model.runtime?.roachClaw.ready ?? false) ? "Ready" : "Warming up",
                        accent: (model.runtime?.roachClaw.ready ?? false) ? RoachTheme.secondary : RoachTheme.primary
                    )

                    if let modelName = model.runtime?.roachClaw.resolvedDefaultModel ?? model.runtime?.roachClaw.defaultModel {
                        RoachBadge(title: modelName, accent: RoachTheme.tertiary)
                    }
                }

                if let error = model.runtime?.roachClaw.error {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(RoachTheme.subduedText)
                }

                if let installedModels = model.runtime?.installedModels, !installedModels.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Installed models")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RoachTheme.text)

                        ForEach(installedModels) { model in
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
                    Text("Services")
                        .font(.headline)
                        .foregroundStyle(RoachTheme.text)

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
                    Text("Download queue")
                        .font(.headline)
                        .foregroundStyle(RoachTheme.text)

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
                    Text("Runtime notes")
                        .font(.headline)
                        .foregroundStyle(RoachTheme.text)

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
