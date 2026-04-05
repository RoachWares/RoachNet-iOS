import SwiftUI

struct ChatView: View {
    @Bindable var model: CompanionAppModel
    @FocusState private var composerFocused: Bool

    private let promptSuggestions = [
        "Summarize my runtime state.",
        "What model am I running right now?",
        "Show the latest RoachBrain highlights.",
        "What should I install next from Apps?",
    ]

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
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        RoachSectionHeader(
                            eyebrow: "RoachClaw",
                            title: model.connection.isConfigured ? "Carry the Mac lane with you." : "Link the Mac lane.",
                            detail: model.currentSession?.title
                                ?? model.pairedMachineName.map { _ in "Linked to your desktop." }
                                ?? "Continue chats, control runtime, and push installs from the phone."
                        )
                    }

                    Spacer(minLength: 12)

                    HStack(spacing: 10) {
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

                HStack(spacing: 10) {
                    RoachMetricTile(
                        label: "Link",
                        value: model.connection.isConfigured ? "Live" : "Needs token",
                        accent: model.connection.isConfigured ? RoachTheme.secondary : RoachTheme.primary
                    )

                    RoachMetricTile(
                        label: "Model",
                        value: model.activeModelName ?? "Waiting for runtime",
                        accent: RoachTheme.tertiary
                    )
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        actionChip("New chat", systemImage: "square.and.pencil") {
                            Task { await model.newChat() }
                        }

                        if model.connection.isConfigured {
                            actionChip("History", systemImage: "clock.arrow.circlepath") {
                                model.historyPresented = true
                            }
                        } else {
                            actionChip("Link Mac", systemImage: "link") {
                                model.settingsPresented = true
                            }
                        }

                        actionChip("Runtime", systemImage: "switch.2") {
                            model.selectedTab = .runtime
                        }

                        actionChip("Apps", systemImage: "square.grid.2x2.fill") {
                            model.selectedTab = .apps
                        }

                        actionChip("Vault", systemImage: "archivebox.fill") {
                            model.selectedTab = .vault
                        }
                    }
                }
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
                detail: "Paste the companion URL and token from your desktop install. Chat, runtime control, vault access, and app installs light up right after.",
                actionTitle: "Link Mac"
            ) {
                model.settingsPresented = true
            }
        } else if model.isBootstrapping, model.currentSession == nil, model.sessionList.isEmpty {
            RoachPanel {
                HStack(spacing: 12) {
                    ProgressView()
                        .tint(RoachTheme.primary)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Loading RoachClaw lane")
                            .font(.headline)
                            .foregroundStyle(RoachTheme.text)
                        Text("Pulling the paired desktop session state.")
                            .font(.subheadline)
                            .foregroundStyle(RoachTheme.subduedText)
                    }
                    Spacer()
                }
            }
        } else if let currentSession = model.currentSession {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if currentSession.messages.isEmpty {
                            RoachPanel {
                                VStack(alignment: .leading, spacing: 14) {
                                    RoachSectionHeader(
                                        eyebrow: "Start here",
                                        title: "This session is ready.",
                                        detail: "Drop a message below or use one of the quick prompts."
                                    )

                                    suggestionGrid
                                }
                            }
                        }

                        LazyVStack(spacing: 12) {
                            ForEach(currentSession.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
                .scrollIndicators(.hidden)
                .refreshable {
                    await model.refreshAll()
                }
                .onChange(of: currentSession.messages.count) { _, _ in
                    guard let lastID = currentSession.messages.last?.id else { return }
                    withAnimation(.easeOut(duration: 0.24)) {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
            }
        } else {
            VStack(spacing: 14) {
                EmptyStateView(
                    title: "Chat from the phone",
                    detail: "Keep RoachClaw close while the real runtime stays on the Mac.",
                    actionTitle: "New chat"
                ) {
                    Task { await model.newChat() }
                }

                RoachPanel {
                    VStack(alignment: .leading, spacing: 14) {
                        RoachSectionHeader(
                            eyebrow: "Prompt ideas",
                            title: "Start with something useful.",
                            detail: nil
                        )

                        suggestionGrid
                    }
                }
            }
        }
    }

    private var suggestionGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(promptSuggestions, id: \.self) { suggestion in
                Button {
                    model.draft = suggestion
                    composerFocused = true
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(RoachTheme.primary)
                        Text(suggestion)
                            .font(.subheadline)
                            .foregroundStyle(RoachTheme.text)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(RoachTheme.elevatedSurface.opacity(0.92))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .strokeBorder(RoachTheme.border, lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
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
                            .frame(width: 28, height: 28)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 30))
                    }
                }
                .foregroundStyle(Color.white)
                .disabled(!model.connection.isConfigured || model.isSending || model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func actionChip(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(RoachTheme.elevatedSurface.opacity(0.92))
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(RoachTheme.border, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(RoachTheme.text)
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
                HStack(spacing: 8) {
                    Text(isUser ? "You" : "RoachClaw")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RoachTheme.subduedText)

                    if !isUser {
                        Image(systemName: "bolt.fill")
                            .font(.caption2)
                            .foregroundStyle(RoachTheme.secondary)
                    }
                }

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
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(session.id == model.currentSession?.id ? RoachTheme.primary : RoachTheme.border)
                                    .frame(width: 10, height: 10)
                                    .padding(.top, 6)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.title)
                                        .foregroundStyle(RoachTheme.text)

                                    Text(session.model ?? "Default model")
                                        .font(.caption)
                                        .foregroundStyle(RoachTheme.subduedText)

                                    if let timestamp = session.timestamp {
                                        Text(formattedRelativeDate(timestamp))
                                            .font(.caption2)
                                            .foregroundStyle(RoachTheme.secondary)
                                    }
                                }
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
