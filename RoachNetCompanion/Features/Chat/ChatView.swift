import PhotosUI
import SwiftUI

struct ChatView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Bindable var model: CompanionAppModel
    @FocusState private var composerFocused: Bool
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var tabBarOverlap: CGFloat = 0

    private var promptSuggestions: [String] {
        [
            "Run a Cookbook check and tell me which model fits this Mac.",
            "Plan a deep research brief I can save to the vault.",
            "Compare two model routes on the same prompt.",
            "Audit memory and skills before they become drawer junk.",
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
                }
                .padding(.horizontal, isCompact ? 14 : 16)
                .padding(.top, isCompact ? 8 : 12)
                // The composer is pinned to the bottom of the safe area (above the floating
                // tab bar and the keyboard) so a long thread can never push it off screen.
                .safeAreaInset(edge: .bottom, spacing: isCompact ? 8 : 12) {
                    composer
                        .padding(.horizontal, isCompact ? 14 : 16)
                        .padding(.bottom, 6 + tabBarOverlap)
                }
                .roachTabBarOverlap($tabBarOverlap)
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
            .onAppear {
                model.refreshVoiceProfiles()
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
                    .font(RoachType.subheadline())
                    .foregroundStyle(RoachTheme.text)
            }
        } else if let bannerText = model.bannerText, horizontalSizeClass != .compact {
            HStack(spacing: 10) {
                Image(systemName: "bolt.fill")
                    .font(RoachType.caption(.bold))
                    .foregroundStyle(RoachTheme.secondary)
                Text(bannerText)
                    .font(RoachType.caption(.semibold))
                    .foregroundStyle(RoachTheme.text)
                    .lineLimit(2)
                Spacer(minLength: 0)
                Text("Live")
                    .font(RoachType.caption2(.bold))
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
                        .font(horizontalSizeClass == .compact ? RoachType.subheadline(.semibold) : RoachType.headline(.semibold))
                        .foregroundStyle(RoachTheme.text)
                        .lineLimit(horizontalSizeClass == .compact ? 1 : 2)

                    if horizontalSizeClass == .compact {
                        HStack(spacing: 8) {
                            RoachBadge(title: currentSession.model ?? "Default model", accent: RoachTheme.primary)

                            if let timestamp = currentSession.messages.last?.createdAt ?? currentSession.timestamp {
                                Text(formattedRelativeDate(timestamp))
                                    .font(RoachType.caption(.semibold))
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
                            .font(RoachType.subheadline(.semibold))
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
                                        .font(RoachType.headline(.semibold))
                                        .foregroundStyle(RoachTheme.text)

                                    Text("Threads stay with your account, not this one phone session. Start with one clean ask or drop straight into the composer.")
                                        .font(RoachType.subheadline())
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
                            .font(RoachType.headline())
                            .foregroundStyle(RoachTheme.text)
                        Text("Pulling the paired desktop thread state.")
                            .font(RoachType.subheadline())
                            .foregroundStyle(RoachTheme.subduedText)
                    }
                    Spacer()
                }
            }
        } else {
            RoachPanel {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Start a thread from the phone.")
                        .font(RoachType.headline(.semibold))
                        .foregroundStyle(RoachTheme.text)

                    Text("RoachClaw keeps the hosted lane open while the private desktop route stays opt-in.")
                        .font(RoachType.subheadline())
                        .foregroundStyle(RoachTheme.subduedText)

                    quickPromptRail

                    Button {
                        Task { await model.newChat() }
                    } label: {
                        Label("New chat", systemImage: "square.and.pencil")
                            .font(RoachType.subheadline(.bold))
                    }
                    .buttonStyle(RoachButtonStyle(kind: .primary, size: .compact))
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
                                .font(RoachType.caption(.bold))
                                .foregroundStyle(RoachTheme.secondary)

                            Text(suggestion)
                                .font(RoachType.subheadline(.semibold))
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
                        .font(RoachType.caption(.bold))
                        .foregroundStyle(RoachTheme.secondary)
                        .textCase(.uppercase)
                }

                if let attachment = model.draftVisionAttachment {
                    visionAttachmentPreview(attachment)
                }

                if horizontalSizeClass == .compact {
                    // iPhone: one row. The full voice strip only shows while dictating.
                    if model.isDictatingDraft {
                        voiceControlStrip
                    }

                    HStack(alignment: .bottom, spacing: 8) {
                        composerUtilityButtons
                        compactMicButton
                        composerField
                        composerSendButton
                    }
                } else {
                    voiceControlStrip

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
                }

                if horizontalSizeClass != .compact {
                    Text(model.connection.isConfigured
                         ? "Hosted lane stays open from the phone. Pair the desktop runtime when you want the private lane."
                         : "Phone lane is local cache until you pair the desktop runtime.")
                        .font(RoachType.caption)
                        .foregroundStyle(RoachTheme.subduedText)
                }
            }
        }
        .padding(.bottom, horizontalSizeClass == .compact ? 2 : 4)
    }

    private var composerUtilityButtons: some View {
        let photoButtonLabel = photoButtonTitle

        return HStack(spacing: 10) {
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

    private var compactMicButton: some View {
        Button {
            Task { await model.toggleDraftDictation() }
        } label: {
            Image(systemName: model.isDictatingDraft ? "stop.fill" : "mic.fill")
                .font(RoachType.subheadline(.semibold))
                .foregroundStyle(model.isDictatingDraft ? Color.black : RoachTheme.secondary)
                .frame(width: 38, height: 38)
                .background(
                    Circle()
                        .fill(model.isDictatingDraft ? RoachTheme.secondary : RoachTheme.elevatedSurface)
                        .overlay(Circle().strokeBorder(RoachTheme.border, lineWidth: 1))
                )
        }
        .buttonStyle(RoachPressableButtonStyle(scale: 0.94))
        .accessibilityLabel(model.isDictatingDraft ? "Stop local speech capture" : "Start local speech capture")
        .accessibilityIdentifier("chat.mic")
    }

    private var voiceControlStrip: some View {
        HStack(spacing: 10) {
            Button {
                Task { await model.toggleDraftDictation() }
            } label: {
                ZStack {
                    VoicePulseMark(isActive: model.isDictatingDraft)

                    Image(systemName: model.isDictatingDraft ? "stop.fill" : "mic.fill")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(model.isDictatingDraft ? Color.black : Color.white)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(model.isDictatingDraft ? RoachTheme.secondary : RoachTheme.primary)
                                .shadow(
                                    color: (model.isDictatingDraft ? RoachTheme.secondary : RoachTheme.primary).opacity(0.42),
                                    radius: 16,
                                    x: 0,
                                    y: 8
                                )
                        )
                }
            }
            .buttonStyle(RoachPressableButtonStyle(scale: 0.94))
            .accessibilityLabel(model.isDictatingDraft ? "Stop local speech capture" : "Start local speech capture")

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(model.voiceEngineTitle)
                        .font(RoachType.caption(.black))
                        .foregroundStyle(RoachTheme.secondary)
                        .textCase(.uppercase)

                    if model.isDictatingDraft {
                        VoiceMeter()
                    }
                }

                Text(model.voiceEngineDetail)
                    .font(RoachType.caption(.semibold))
                    .foregroundStyle(RoachTheme.subduedText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.74)
            }

            Spacer(minLength: 6)

            if let latestAssistantMessage {
                Button {
                    model.toggleSpeech(for: latestAssistantMessage)
                } label: {
                    Image(systemName: model.speakingMessageID == latestAssistantMessage.id ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(model.speakingMessageID == latestAssistantMessage.id ? Color.black : RoachTheme.tertiary)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(model.speakingMessageID == latestAssistantMessage.id ? RoachTheme.secondary : RoachTheme.elevatedSurface)
                                .overlay(
                                    Circle()
                                        .strokeBorder(RoachTheme.border, lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(RoachPressableButtonStyle(scale: 0.94))
                .accessibilityLabel(model.speakingMessageID == latestAssistantMessage.id ? "Stop readback" : "Read latest reply")
            }

            Menu {
                if model.availableVoiceProfiles.isEmpty {
                    Text("No installed voices found")
                } else {
                    ForEach(Array(model.availableVoiceProfiles.prefix(24))) { profile in
                        Button {
                            model.selectVoiceProfile(profile)
                        } label: {
                            Label(
                                "\(profile.title) · \(profile.subtitle)",
                                systemImage: profile.id == model.selectedVoiceProfileID ? "checkmark.circle.fill" : "waveform"
                            )
                        }
                    }
                }

                Divider()

                Button {
                    model.refreshVoiceProfiles()
                } label: {
                    Label("Refresh installed voices", systemImage: "arrow.clockwise")
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.2.square")
                        .font(RoachType.caption(.black))
                    Text("Voice")
                        .font(RoachType.caption(.black))
                }
                .foregroundStyle(RoachTheme.text)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(
                    Capsule(style: .continuous)
                        .fill(RoachTheme.elevatedSurface.opacity(0.92))
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(RoachTheme.border, lineWidth: 1)
                        )
                )
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            RoachTheme.elevatedSurface.opacity(0.96),
                            RoachTheme.surface.opacity(0.90),
                            RoachTheme.void.opacity(0.12),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    RoachTheme.secondary.opacity(model.isDictatingDraft ? 0.56 : 0.24),
                                    RoachTheme.primary.opacity(0.22),
                                    RoachTheme.border,
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: model.isDictatingDraft)
        .animation(.spring(response: 0.28, dampingFraction: 0.78), value: model.selectedVoiceProfileID)
    }

    private var composerField: some View {
        TextField("Message RoachClaw or the offline cache", text: $model.draft, axis: .vertical)
            .focused($composerFocused)
            .accessibilityIdentifier("chat.composer")
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

                if horizontalSizeClass != .compact {
                    Text(model.isSending ? "Sending" : "Send")
                        .font(RoachType.subheadline(.bold))
                }
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, horizontalSizeClass == .compact ? 9 : 15)
            .padding(.vertical, horizontalSizeClass == .compact ? 8 : 12)
            .background(
                Capsule(style: .continuous)
                    .fill(RoachTheme.primary)
                    .shadow(color: RoachTheme.primary.opacity(0.35), radius: 16, x: 0, y: 12)
            )
        }
        .buttonStyle(RoachPressableButtonStyle(scale: 0.972))
        .accessibilityIdentifier("chat.send")
        .accessibilityLabel(model.isSending ? "Sending" : "Send")
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
                                .font(RoachType.title3(.semibold))
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
                            .font(RoachType.subheadline(.semibold))
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
                    .font(RoachType.caption(.semibold))
                    .foregroundStyle(RoachTheme.secondary)
                }

                Text(attachment.summary)
                    .font(RoachType.caption)
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
                .font(RoachType.subheadline(.semibold))
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

private struct VoicePulseMark: View {
    let isActive: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: !isActive)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
            let pulse = isActive ? CGFloat((sin(phase * 5.4) + 1) / 2) : 0

            Circle()
                .strokeBorder(RoachTheme.secondary.opacity(isActive ? 0.20 + (pulse * 0.34) : 0), lineWidth: 2)
                .frame(width: 48 + (pulse * 8), height: 48 + (pulse * 8))
                .blur(radius: isActive ? 0.2 : 0)
        }
        .frame(width: 52, height: 52)
    }
}

private struct VoiceMeter: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 18.0)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate

            HStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { index in
                    let height = 5 + CGFloat((sin(phase * 7.0 + Double(index) * 0.82) + 1) / 2) * 9
                    Capsule(style: .continuous)
                        .fill(RoachTheme.secondary)
                        .frame(width: 3, height: height)
                        .shadow(color: RoachTheme.secondary.opacity(0.35), radius: 5, x: 0, y: 0)
                }
            }
        }
        .frame(width: 24, height: 16)
    }
}

private struct ComposerUtilityGlyph: View {
    let title: String
    let systemImage: String
    let accent: Color

    var body: some View {
        Image(systemName: systemImage)
            .font(RoachType.subheadline(.semibold))
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
                        .font(RoachType.caption(.semibold))
                        .foregroundStyle(RoachTheme.subduedText)

                    if !isUser {
                        Image(systemName: "bolt.fill")
                            .font(RoachType.caption2)
                            .foregroundStyle(RoachTheme.secondary)
                    }

                    Spacer(minLength: 8)

                    if let onSpeak {
                        Button(action: onSpeak) {
                            Image(systemName: isSpeaking ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(RoachType.caption(.semibold))
                                .foregroundStyle(isSpeaking ? RoachTheme.secondary : RoachTheme.tertiary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text(message.content)
                    .font(RoachType.body)
                    .foregroundStyle(RoachTheme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(formattedRelativeDate(message.createdAt))
                    .font(RoachType.caption2)
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
                                        RoachTheme.elevatedSurface.opacity(0.82),
                                        RoachTheme.void.opacity(0.74),
                                    ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    (isUser ? RoachTheme.primary : RoachTheme.cyan).opacity(isUser ? 0.16 : 0.05),
                                    Color.clear,
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
                                        .font(RoachType.caption)
                                        .foregroundStyle(RoachTheme.subduedText)

                                    if let timestamp = session.timestamp {
                                        Text(formattedRelativeDate(timestamp))
                                            .font(RoachType.caption2)
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
