import SwiftUI

struct ChatView: View {
    @Bindable var model: CompanionAppModel
    @FocusState private var composerFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                RoachBackdrop()

                VStack(spacing: 14) {
                    header
                    banner
                    content
                    composer
                }
                .padding(16)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: Binding(
                get: { model.historyPresented },
                set: { model.historyPresented = $0 }
            )) {
                SessionHistorySheet(model: model)
            }
        }
    }

    private var header: some View {
        RoachPanel {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("RoachClaw")
                        .font(.title2.weight(.black))
                        .foregroundStyle(RoachTheme.text)

                    Text(model.currentSession?.title ?? (model.pairedMachineName.map { "Linked to \($0)." } ?? "Continue the Mac lane from here."))
                        .font(.subheadline)
                        .foregroundStyle(RoachTheme.subduedText)

                    HStack(spacing: 8) {
                        RoachBadge(
                            title: model.connection.isConfigured ? "Linked" : "Unlinked",
                            accent: model.connection.isConfigured ? RoachTheme.secondary : RoachTheme.primary
                        )

                        if let modelName = model.currentSession?.model {
                            RoachBadge(title: modelName, accent: RoachTheme.tertiary)
                        }
                    }
                }

                Spacer(minLength: 12)

                HStack(spacing: 10) {
                    if model.connection.isConfigured {
                        Button {
                            model.historyPresented = true
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.headline)
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Button("Link Mac") {
                            model.settingsPresented = true
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(RoachTheme.primary)
                    }

                    Button {
                        model.settingsPresented = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.headline)
                    }
                    .buttonStyle(.bordered)
                }
                .tint(RoachTheme.secondary)
            }
        }
    }

    @ViewBuilder
    private var banner: some View {
        if let errorText = model.errorText {
            RoachPanel {
                Text(errorText)
                    .font(.subheadline)
                    .foregroundStyle(Color.white)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(RoachTheme.primary.opacity(0.45), lineWidth: 1)
            )
        } else if model.connection.isConfigured, let bannerText = model.bannerText {
            RoachPanel {
                Text(bannerText)
                    .font(.subheadline)
                    .foregroundStyle(RoachTheme.text)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if !model.connection.isConfigured {
            EmptyStateView(
                title: "Link the Mac lane",
                detail: "Paste the companion URL and token from your desktop install. Chats, vault access, and app installs start working right after.",
                actionTitle: "Link Mac"
            ) {
                model.settingsPresented = true
            }
        } else if let currentSession = model.currentSession {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(currentSession.messages) { message in
                        MessageBubble(message: message)
                    }
                }
                .padding(.vertical, 6)
            }
            .scrollIndicators(.hidden)
        } else {
            EmptyStateView(
                title: "Chat from the phone",
                detail: "Pick up the same sessions your Mac runtime already knows about.",
                actionTitle: "New chat"
            ) {
                Task { await model.newChat() }
            }
        }
    }

    private var composer: some View {
        RoachPanel {
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Message RoachClaw", text: $model.draft, axis: .vertical)
                    .focused($composerFocused)
                    .textInputAutocapitalization(.sentences)
                    .lineLimit(1...6)
                    .padding(12)
                    .background(RoachTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .disabled(!model.connection.isConfigured)

                Button {
                    Task {
                        await model.sendDraft()
                    }
                } label: {
                    if model.isSending {
                        ProgressView()
                            .tint(Color.white)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                    }
                }
                .foregroundStyle(Color.white)
                .disabled(!model.connection.isConfigured || model.isSending || model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

private struct MessageBubble: View {
    let message: CompanionChatMessage

    private var isUser: Bool {
        message.role.lowercased() == "user"
    }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }

            VStack(alignment: .leading, spacing: 8) {
                Text(isUser ? "You" : "RoachClaw")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RoachTheme.subduedText)

                Text(message.content)
                    .font(.body)
                    .foregroundStyle(RoachTheme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(formattedRelativeDate(message.createdAt))
                    .font(.caption2)
                    .foregroundStyle(RoachTheme.subduedText)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(isUser ? RoachTheme.primary.opacity(0.28) : RoachTheme.surface.opacity(0.98))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .strokeBorder((isUser ? RoachTheme.primary : RoachTheme.border).opacity(0.55), lineWidth: 1)
                    )
            )
            .frame(maxWidth: 320, alignment: .leading)

            if !isUser { Spacer(minLength: 40) }
        }
    }
}

private struct SessionHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: CompanionAppModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        dismiss()
                        Task { await model.newChat() }
                    } label: {
                        Label("Start new chat", systemImage: "square.and.pencil")
                    }
                }

                Section("History") {
                    ForEach(model.sessionList) { session in
                        Button {
                            dismiss()
                            Task {
                                try? await model.loadSession(session.id)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.title)
                                    .foregroundStyle(RoachTheme.text)
                                Text(session.model ?? "Default model")
                                    .font(.caption)
                                    .foregroundStyle(RoachTheme.subduedText)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(RoachBackdrop())
            .navigationTitle("Chats")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
