import SwiftUI

struct VaultView: View {
    @Bindable var model: CompanionAppModel

    var body: some View {
        NavigationStack {
            ZStack {
                RoachBackdrop()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if let vault = model.vault {
                            summaryPanel(vault)
                            notesPanel(vault)
                            knowledgePanel(vault)
                            archivesPanel(vault)
                        } else if model.connection.isConfigured, model.isBootstrapping {
                            RoachPanel {
                                HStack(spacing: 12) {
                                    ProgressView()
                                        .tint(RoachTheme.primary)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Loading Vault")
                                            .font(.headline)
                                            .foregroundStyle(RoachTheme.text)
                                        Text("Pulling RoachBrain, files, and archive summaries from the paired Mac.")
                                            .font(.subheadline)
                                            .foregroundStyle(RoachTheme.subduedText)
                                    }
                                    Spacer()
                                }
                            }
                        } else {
                            EmptyStateView(
                                title: "Vault stays on the Mac",
                                detail: "Link the companion lane to browse RoachBrain, archive stubs, and knowledge files from the phone.",
                                actionTitle: "Open connection"
                            ) {
                                model.settingsPresented = true
                            }
                        }
                    }
                    .padding(16)
                }
                .refreshable {
                    await model.refreshAll()
                }
            }
            .navigationTitle("Vault")
        }
    }

    private func summaryPanel(_ vault: CompanionVaultSummary) -> some View {
        RoachPanel {
            VStack(alignment: .leading, spacing: 12) {
                RoachSectionHeader(
                    eyebrow: "Vault",
                    title: "The Mac shelf, from the phone.",
                    detail: "RoachBrain notes, indexed files, and site archives stay browseable without opening the full desktop shell."
                )

                HStack(spacing: 10) {
                    RoachMetricTile(label: "RoachBrain", value: "\(vault.roachBrain.count)", accent: RoachTheme.primary)
                    RoachMetricTile(label: "Files", value: "\(vault.knowledgeFiles.count)", accent: RoachTheme.secondary)
                    RoachMetricTile(label: "Archives", value: "\(vault.siteArchives.count)", accent: RoachTheme.tertiary)
                }
            }
        }
    }

    private func notesPanel(_ vault: CompanionVaultSummary) -> some View {
        RoachPanel {
            VStack(alignment: .leading, spacing: 12) {
                RoachSectionHeader(
                    eyebrow: "RoachBrain",
                    title: "Pinned memory and recent notes.",
                    detail: vault.roachBrain.isEmpty ? "No captured memory yet." : nil
                )

                if vault.roachBrain.isEmpty {
                    Text("No captured memory yet.")
                        .font(.subheadline)
                        .foregroundStyle(RoachTheme.subduedText)
                } else {
                    ForEach(vault.roachBrain.prefix(6)) { memory in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(memory.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(RoachTheme.text)
                                Spacer()
                                if memory.pinned {
                                    Image(systemName: "pin.fill")
                                        .foregroundStyle(RoachTheme.primary)
                                }
                            }

                            Text(memory.summary)
                                .font(.subheadline)
                                .foregroundStyle(RoachTheme.subduedText)

                            Text(memory.tags.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(RoachTheme.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private func knowledgePanel(_ vault: CompanionVaultSummary) -> some View {
        RoachPanel {
            VStack(alignment: .leading, spacing: 12) {
                RoachSectionHeader(
                    eyebrow: "Knowledge files",
                    title: "Indexed docs in the vault.",
                    detail: vault.knowledgeFiles.isEmpty ? "No indexed files yet." : nil
                )

                if vault.knowledgeFiles.isEmpty {
                    Text("No indexed files yet.")
                        .font(.subheadline)
                        .foregroundStyle(RoachTheme.subduedText)
                } else {
                    ForEach(vault.knowledgeFiles.prefix(8), id: \.self) { file in
                        Text(file)
                            .font(.subheadline.monospaced())
                            .foregroundStyle(RoachTheme.text)
                    }
                }
            }
        }
    }

    private func archivesPanel(_ vault: CompanionVaultSummary) -> some View {
        RoachPanel {
            VStack(alignment: .leading, spacing: 12) {
                RoachSectionHeader(
                    eyebrow: "Site archives",
                    title: "Offline captures and saved shelves.",
                    detail: vault.siteArchives.isEmpty ? "No archives yet." : nil
                )

                if vault.siteArchives.isEmpty {
                    Text("No archives yet.")
                        .font(.subheadline)
                        .foregroundStyle(RoachTheme.subduedText)
                } else {
                    ForEach(vault.siteArchives.prefix(6)) { archive in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(archive.title ?? archive.slug)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(RoachTheme.text)
                            Text(archive.note ?? archive.sourceUrl ?? "Offline archive ready.")
                                .font(.caption)
                                .foregroundStyle(RoachTheme.subduedText)
                        }
                    }
                }
            }
        }
    }
}
