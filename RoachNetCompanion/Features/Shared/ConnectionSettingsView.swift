import SwiftUI

struct ConnectionSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: CompanionAppModel

    var body: some View {
        ZStack {
            RoachBackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    RoachPanel {
                        VStack(alignment: .leading, spacing: 14) {
                            RoachSectionHeader(
                                eyebrow: "Pairing",
                                title: "Link this phone to your Mac.",
                                detail: "Point the app at the companion URL and token from your RoachNet desktop runtime."
                            )

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Companion URL")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(RoachTheme.subduedText)

                                TextField("http://192.168.1.10:38111", text: $model.connection.baseURL)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .padding(12)
                                    .background(RoachTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Companion token")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(RoachTheme.subduedText)

                                SecureField("Paste the RoachNet companion token", text: $model.connection.token)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .padding(12)
                                    .background(RoachTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }
                    }

                    RoachPanel {
                        VStack(alignment: .leading, spacing: 10) {
                            RoachSectionHeader(
                                eyebrow: "What it opens",
                                title: "Chat, vault, runtime, and installs.",
                                detail: "The same token-gated bridge handles RoachClaw chat, RoachBrain reads, service controls, and Apps installs."
                            )

                            RoachBadge(
                                title: model.connection.isConfigured ? "Configured" : "Needs setup",
                                accent: model.connection.isConfigured ? RoachTheme.secondary : RoachTheme.primary
                            )

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Simulator default: http://127.0.0.1:38111")
                                Text("Phone default: http://<your-mac-ip>:38111")
                            }
                            .font(.caption)
                            .foregroundStyle(RoachTheme.subduedText)
                        }
                    }

                    HStack(spacing: 12) {
                        Button("Save & Test") {
                            Task {
                                model.connection.save()
                                await model.refreshAll()
                                dismiss()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(RoachTheme.primary)

                        Button("Refresh") {
                            Task {
                                await model.refreshAll()
                            }
                        }
                        .buttonStyle(.bordered)
                        .tint(RoachTheme.secondary)
                    }
                }
                .padding(18)
            }
        }
        .navigationTitle("Connection")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}
