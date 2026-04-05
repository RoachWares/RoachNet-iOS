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
                            notesPanel(vault)
                            knowledgePanel(vault)
                            archivesPanel(vault)
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
            }
            .navigationTitle("Vault")
        }
    }

    private func notesPanel(_ vault: CompanionVaultSummary) -> some View {
        RoachPanel {
            VStack(alignment: .leading, spacing: 12) {
                Text("RoachBrain")
                    .font(.headline)
                    .foregroundStyle(RoachTheme.text)

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
                Text("Knowledge files")
                    .font(.headline)
                    .foregroundStyle(RoachTheme.text)

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
                Text("Site archives")
                    .font(.headline)
                    .foregroundStyle(RoachTheme.text)

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

