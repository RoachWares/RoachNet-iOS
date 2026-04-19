import PhotosUI
import SwiftUI

struct ChatView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Bindable var model: CompanionAppModel
    @FocusState private var composerFocused: Bool
    @State private var selectedPhotoItem: PhotosPickerItem?

    private var promptSuggestions: [String] {
        [
            "Give me the next useful move.",
            "Summarize what RoachNet is doing right now.",
            "Turn the latest local context into one clean brief.",
            "What still works if the Mac goes dark?",
            model.recentInstallItems.first.map { _ in "What did I just send from Apps, and what happens next?" } ?? "What belongs on this shelf next?",
        ]
    }

    private var latestAssistantMessage: CompanionChatMessage? {
        model.currentSession?.messages.last(where: { $0.role.lowercased() == "assistant" })
    }

    private var headerDetail: String {
        if model.runtime?.account?.linked == true {
            return "Hosted lane open. The private route still stays opt-in."
        }

        if model.pairedMachineName != nil {
            return "Paired to the desktop, with cached state still close on the phone."
        }

        return "The thread stays readable even when the Mac is away."
    }

    private var photoButtonTitle: String {
        model.draftVisionAttachment == nil ? "Add image" : "Replace image"
    }

    var body: some View {
        let isCompact = horizontalSizeClass == .compact

        NavigationStack {
            ZStack {
                RoachBackdrop()

                VStack(spacing: isCompact ? 10 : 14) {
                    header
                    banner
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    composer
                }
                .padding(.horizontal, isCompact ? 14 : 16)
                .padding(.top, isCompact ? 8 : 12)
            }
            .navigationBarHidden(true)
            .sheet(isPresented: Binding(
                get: { model.historyPresented },
                set: { model.historyPresented = $0 }
            )) {
                SessionHistorySheet(model: model)
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let newItem else { return }
                Task {
                    if let data = try? await newItem.loadTransferable(type: Data.self) {
                        await model.attachVisionImage(data: data)
                    }
                    selectedPhotoItem = nil
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: horizontalSizeClass == .compact ? 6 : 10) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    RoachShellDock(
                        title: "RoachClaw",
                        detail: model.connection.isConfigured ? "Pick the thread up anywhere." : "The thread still works when the Mac goes dark.",
                        accent: RoachTheme.primary,
                        status: model.connection.isConfigured ? "Hosted lane open" : "Phone lane only",
                        secondaryStatus: model.runtime?.account?.linked == true ? "Account linked" : "Account local"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    headerButtons
                }

                VStack(alignment: .leading, spacing: 10) {
                    RoachShellDock(
                        title: "RoachClaw",
                        detail: model.connection.isConfigured ? "Pick the thread up anywhere." : "The thread still works when the Mac goes dark.",
                        accent: RoachTheme.primary,
                        status: model.connection.isConfigured ? "Hosted lane open" : "Phone lane only",
                        secondaryStatus: model.runtime?.account?.linked == true ? "Account linked" : "Account local"
                    )

                    headerButtons
                }
            }

            if horizontalSizeClass != .compact {
                conversationStatusRow
            }
        }
    }

    private var headerButtons: some View {
        HStack(spacing: 8) {
            headerIconButton("New", systemImage: "square.and.pencil") {
                Task { await model.newChat() }
            }

            if model.connection.isConfigured {
                headerIconButton("History", systemImage: "clock.arrow.circlepath") {
                    model.historyPresented = true
                }
            }

            headerIconButton("Settings", systemImage: "slider.horizontal.3") {
                model.settingsPresented = true
            }
        }
    }

    private var conversationStatusRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                RoachStatusPill(
                    title: model.connection.isConfigured ? "Paired lane" : "Phone-only cache",
                    accent: model.connection.isConfigured ? RoachTheme.secondary : RoachTheme.primary
                )
                RoachStatusPill(
                    title: model.runtime?.account?.linked == true ? "Account linked" : "Account local",
                    accent: model.runtime?.account?.linked == true ? RoachTheme.tertiary : RoachTheme.primary
                )
                if horizontalSizeClass != .compact {
                    RoachStatusPill(
                        title: model.queuedInstallCount > 0 ? "\(model.queuedInstallCount) queued" : "Queue clear",
                        accent: model.queuedInstallCount > 0 ? RoachTheme.primary : RoachTheme.tertiary
                    )
                }
            }
            .padding(.vertical, 1)
        }
    }

    @ViewBuilder
    private var banner: some View {
        if let errorText = model.errorText {
            bannerShell(accent: RoachTheme.primary) {
                Text(errorText)
                    .font(.subheadline)
                    .foregroundStyle(Color.white)
            }
        } else if let bannerText = model.bannerText, horizontalSizeClass != .compact {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(RoachTheme.secondary)
                Text(bannerText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RoachTheme.text)
                    .lineLimit(2)
                Spacer(minLength: 0)
                Text("Live")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(RoachTheme.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(RoachTheme.surface.opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .strokeBorder(RoachTheme.secondary.opacity(0.26), lineWidth: 1)
                    )
            )
        }
    }

    private var compactThreadPills: some View {
        HStack(spacing: 8) {
            RoachBadge(title: model.connection.isConfigured ? "Hosted lane" : "Phone lane", accent: RoachTheme.primary)
            if model.runtime?.account?.linked == true {
                RoachBadge(title: "Account linked", accent: RoachTheme.tertiary)
            }
        }
    }

    private var contentHeaderSpacing: CGFloat {
        horizontalSizeClass == .compact ? 10 : 14
    }

    @ViewBuilder
    private var currentSessionLead: some View {
        if horizontalSizeClass == .compact {
            compactThreadPills
        } else {
            EmptyView()
        }
    }

    private func threadHeader(_ currentSession: CompanionChatSessionDetail) -> some View {
        VStack(alignment: .leading, spacing: contentHeaderSpacing) {
            currentSessionLead

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(currentSession.title.isEmpty ? "Current thread" : currentSession.title)
                        .font(horizontalSizeClass == .compact ? .subheadline.weight(.semibold) : .headline.weight(.semibold))
                        .foregroundStyle(RoachTheme.text)
                        .lineLimit(horizontalSizeClass == .compact ? 1 : 2)

                    if horizontalSizeClass == .compact {
                        HStack(spacing: 8) {
                            RoachBadge(title: currentSession.model ?? "Default model", accent: RoachTheme.primary)

                            if let timestamp = currentSession.messages.last?.createdAt ?? currentSession.timestamp {
                                Text(formattedRelativeDate(timestamp))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(RoachTheme.subduedText)
                                    .lineLimit(1)
                            }
                        }
                    } else {
                        HStack(spacing: 8) {
                            RoachBadge(title: currentSession.model ?? "Default model", accent: RoachTheme.primary)

                            if let timestamp = currentSession.messages.last?.createdAt ?? currentSession.timestamp {
                                RoachBadge(title: "Updated \(formattedRelativeDate(timestamp))", accent: RoachTheme.tertiary)
                            }
                        }
                    }
                }

                Spacer(minLength: 8)

                if let latestAssistantMessage {
                    Button {
                        model.toggleSpeech(for: latestAssistantMessage)
                    } label: {
                        Image(systemName: model.speakingMessageID == latestAssistantMessage.id ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(model.speakingMessageID == latestAssistantMessage.id ? RoachTheme.secondary : RoachTheme.tertiary)
                            .frame(width: 38, height: 38)
                            .background(
                                Circle()
                                    .fill(RoachTheme.elevatedSurface)
                                    .overlay(
                                        Circle()
                                            .strokeBorder(RoachTheme.border, lineWidth: 1)
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let currentSession = model.currentSession {
            RoachPanel {
                VStack(alignment: .leading, spacing: 14) {
                    threadHeader(currentSession)

                    if currentSession.messages.isEmpty {
                        VStack(alignment: .leading, spacing: 18) {
                            HStack(alignment: .top, spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(RoachTheme.tertiary.opacity(0.18))
                                        .frame(width: 52, height: 52)

                                    Image(systemName: "message.badge.waveform.fill")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(RoachTheme.tertiary)
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("What can RoachClaw help with?")
                                        .font(.headline.weight(.semibold))
                                        .foregroundStyle(RoachTheme.text)

                                    Text("Threads stay with your account, not this one phone session. Start with one clean ask or drop straight into the composer.")
                                        .font(.subheadline)
                                        .foregroundStyle(RoachTheme.subduedText)
                                }
                            }

                            quickPromptRail

                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 8) {
                            RoachBadge(title: "Account-scoped threads", accent: RoachTheme.primary)
                            RoachBadge(title: "Hosted lane ready", accent: RoachTheme.tertiary)
                            RoachBadge(title: "Private route opt-in", accent: RoachTheme.secondary)
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    RoachBadge(title: "Account-scoped threads", accent: RoachTheme.primary)
                                    RoachBadge(title: "Hosted lane ready", accent: RoachTheme.tertiary)
                                    RoachBadge(title: "Local bridge stays opt-in", accent: RoachTheme.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(.top, 8)
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(currentSession.messages) { message in
                                        MessageBubble(
                                            message: message,
                                            isSpeaking: model.speakingMessageID == message.id,
                                            onSpeak: message.role.lowercased() == "user"
                                                ? nil
                                                : { model.toggleSpeech(for: message) }
                                        )
                                            .id(message.id)
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
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
            }
        } else if !model.connection.isConfigured {
            EmptyStateView(
                title: "Link the Mac lane",
                detail: "Paste the companion URL and token from the desktop install. Chat, runtime control, vault access, and app installs light up right after.",
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
                        Text("Loading the RoachClaw lane")
                            .font(.headline)
                            .foregroundStyle(RoachTheme.text)
                        Text("Pulling the paired desktop thread state.")
                            .font(.subheadline)
                            .foregroundStyle(RoachTheme.subduedText)
                    }
                    Spacer()
                }
            }
        } else {
            RoachPanel {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Start a thread from the phone.")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(RoachTheme.text)

                    Text("RoachClaw keeps the hosted lane open while the private desktop route stays opt-in.")
                        .font(.subheadline)
                        .foregroundStyle(RoachTheme.subduedText)

                    quickPromptRail

                    Button {
                        Task { await model.newChat() }
                    } label: {
                        Label("New chat", systemImage: "square.and.pencil")
                            .font(.subheadline.weight(.bold))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(RoachTheme.primary)
                }
            }
        }
    }

    private var quickPromptRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(promptSuggestions, id: \.self) { suggestion in
                    Button {
                        model.draft = suggestion
                        composerFocused = true
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Quick start", systemImage: "sparkles")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(RoachTheme.secondary)

                            Text(suggestion)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(RoachTheme.text)
                                .multilineTextAlignment(.leading)
                                .frame(width: horizontalSizeClass == .compact ? 220 : 248, alignment: .leading)
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
            .padding(.vertical, 1)
        }
    }

    private var composer: some View {
        RoachPanel {
            VStack(alignment: .leading, spacing: horizontalSizeClass == .compact ? 10 : 12) {
                if horizontalSizeClass != .compact {
                    Text("Reply")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(RoachTheme.secondary)
                        .textCase(.uppercase)
                }

                if let attachment = model.draftVisionAttachment {
                    visionAttachmentPreview(attachment)
                }

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .bottom, spacing: 12) {
                        composerUtilityButtons
                        composerField
                        composerSendButton
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        composerUtilityButtons

                        HStack(alignment: .bottom, spacing: 12) {
                            composerField
                            composerSendButton
                        }
                    }
                }

                if horizontalSizeClass != .compact {
                    Text(model.connection.isConfigured
                         ? "Hosted lane stays open from the phone. Pair the desktop runtime when you want the private lane."
                         : "Phone lane is local cache until you pair the desktop runtime.")
                        .font(.caption)
                        .foregroundStyle(RoachTheme.subduedText)
                }
            }
        }
        .padding(.bottom, horizontalSizeClass == .compact ? 2 : 4)
    }

    private var composerUtilityButtons: some View {
        let photoButtonLabel = photoButtonTitle

        return HStack(spacing: 10) {
            Button {
                Task { await model.toggleDraftDictation() }
            } label: {
                ComposerUtilityGlyph(
                    title: model.isDictatingDraft ? "Stop" : "Voice",
                    systemImage: model.isDictatingDraft ? "waveform.circle.fill" : "mic.circle.fill",
                    accent: model.isDictatingDraft ? RoachTheme.secondary : RoachTheme.primary
                )
            }
            .buttonStyle(.plain)

            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                ComposerUtilityGlyph(
                    title: photoButtonLabel == "Add image" ? "Image" : "Replace",
                    systemImage: "photo.fill.on.rectangle.fill",
                    accent: RoachTheme.tertiary
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var composerField: some View {
        TextField("Message RoachClaw or the offline cache", text: $model.draft, axis: .vertical)
            .focused($composerFocused)
            .textInputAutocapitalization(.sentences)
            .lineLimit(horizontalSizeClass == .compact ? 1...4 : 1...5)
            .padding(horizontalSizeClass == .compact ? 12 : 14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(RoachTheme.elevatedSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(RoachTheme.border, lineWidth: 1)
                    )
            )
    }

    private var composerSendButton: some View {
        Button {
            Task {
                await model.sendDraft()
            }
        } label: {
            HStack(spacing: 10) {
                if model.isSending {
                    ProgressView()
                        .tint(Color.white)
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 22, weight: .semibold))
                }

                Text(model.isSending ? "Sending" : "Send")
                    .font(.subheadline.weight(.bold))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            .background(
                Capsule(style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [RoachTheme.primary, RoachTheme.secondary.opacity(0.76)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(model.isSending || !model.canSendDraft)
        .opacity(model.isSending || !model.canSendDraft ? 0.62 : 1)
    }

    private func visionAttachmentPreview(_ attachment: CompanionVisionAttachment) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Group {
                if let previewImage = attachment.previewImage {
                    Image(uiImage: previewImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(RoachTheme.primary.opacity(0.18))
                        .overlay(
                            Image(systemName: "sparkles.tv")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(RoachTheme.primary)
                        )
                }
            }
            .frame(width: 78, height: 78)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(RoachTheme.border, lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(attachment.filename)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(RoachTheme.text)
                            .lineLimit(1)

                        HStack(spacing: 8) {
                            RoachBadge(title: "Vision armed", accent: RoachTheme.primary)
                            RoachBadge(title: "\(attachment.pixelWidth)x\(attachment.pixelHeight)", accent: RoachTheme.tertiary)
                        }
                    }

                    Spacer(minLength: 8)

                    Button("Remove") {
                        model.clearDraftVisionAttachment()
                    }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RoachTheme.secondary)
                }

                Text(attachment.summary)
                    .font(.caption)
                    .foregroundStyle(RoachTheme.subduedText)
                    .lineLimit(3)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(RoachTheme.surface.opacity(0.98))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(RoachTheme.border, lineWidth: 1)
                )
        )
    }

    private func bannerShell<Content: View>(accent: Color, @ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(RoachTheme.surface.opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(accent.opacity(0.34), lineWidth: 1)
                    )
            )
    }

    private func headerIconButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(RoachTheme.text)
                .frame(width: 38, height: 38)
                .background(
                    Circle()
                        .fill(RoachTheme.elevatedSurface)
                        .overlay(
                            Circle()
                                .strokeBorder(RoachTheme.border, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

}

private struct ComposerUtilityGlyph: View {
    let title: String
    let systemImage: String
    let accent: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(accent)
            .frame(width: 38, height: 38)
            .background(
                Circle()
                    .fill(RoachTheme.elevatedSurface)
                    .overlay(
                        Circle()
                            .strokeBorder(RoachTheme.border, lineWidth: 1)
                    )
            )
            .accessibilityLabel(title)
    }
}

private struct MessageBubble: View {
    let message: CompanionChatMessage
    let isSpeaking: Bool
    let onSpeak: (() -> Void)?

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

                    Spacer(minLength: 8)

                    if let onSpeak {
                        Button(action: onSpeak) {
                            Image(systemName: isSpeaking ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(isSpeaking ? RoachTheme.secondary : RoachTheme.tertiary)
                        }
                        .buttonStyle(.plain)
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
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: isUser
                                    ? [
                                        RoachTheme.primary.opacity(0.28),
                                        RoachTheme.primary.opacity(0.16),
                                        RoachTheme.surface.opacity(0.96),
                                    ]
                                    : [
                                        RoachTheme.surface.opacity(0.98),
                                        RoachTheme.elevatedSurface.opacity(0.92),
                                        Color.black.opacity(0.10),
                                    ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    (isUser ? RoachTheme.primary : RoachTheme.secondary).opacity(0.16),
                                    Color.clear,
                                    RoachTheme.tertiary.opacity(0.06),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder((isUser ? RoachTheme.primary : RoachTheme.border).opacity(0.55), lineWidth: 1)
                )
            )
            .frame(maxWidth: 348, alignment: .leading)

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
