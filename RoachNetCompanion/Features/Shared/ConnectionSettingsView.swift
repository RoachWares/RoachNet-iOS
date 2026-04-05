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
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Link to your Mac")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(RoachTheme.text)

                            Text("Point this app at the RoachNet companion lane running on your desktop.")
                                .font(.subheadline)
                                .foregroundStyle(RoachTheme.subduedText)

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
                            Text("What it reaches")
                                .font(.headline)
                                .foregroundStyle(RoachTheme.text)

                            Text("Chats, RoachBrain, runtime status, and Apps installs all run through this one token-gated lane.")
                                .font(.subheadline)
                                .foregroundStyle(RoachTheme.subduedText)

                            RoachBadge(
                                title: model.connection.isConfigured ? "Configured" : "Needs setup",
                                accent: model.connection.isConfigured ? RoachTheme.secondary : RoachTheme.primary
                            )
                        }
                    }

                    HStack(spacing: 12) {
                        Button("Save") {
                            model.connection.save()
                            dismiss()
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

