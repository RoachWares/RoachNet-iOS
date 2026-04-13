import SwiftUI

struct CompanionRootView: View {
    @State private var model = CompanionAppModel()
    @State private var didPresentInitialSettings = false
    private let shellSpring = Animation.spring(response: 0.32, dampingFraction: 0.86)

    private var tabItems: [RoachTabBarItem] {
        [
            RoachTabBarItem(tab: .chat, title: "Chat", systemImage: "message.fill", accent: RoachTheme.primary),
            RoachTabBarItem(tab: .vault, title: "Vault", systemImage: "archivebox.fill", accent: RoachTheme.secondary),
            RoachTabBarItem(tab: .apps, title: "Apps", systemImage: "square.grid.2x2.fill", accent: RoachTheme.tertiary),
            RoachTabBarItem(tab: .runtime, title: "Runtime", systemImage: "switch.2", accent: RoachTheme.secondary),
        ]
    }

    private var shellAccent: Color {
        switch model.selectedTab {
        case .chat:
            return RoachTheme.primary
        case .vault:
            return RoachTheme.secondary
        case .apps:
            return RoachTheme.tertiary
        case .runtime:
            return RoachTheme.secondary
        }
    }

    private var shellTitle: String {
        switch model.selectedTab {
        case .chat:
            return "RoachClaw"
        case .vault:
            return "Vault"
        case .apps:
            return "Apps"
        case .runtime:
            return "Runtime"
        }
    }

    private var shellDetail: String {
        switch model.selectedTab {
        case .chat:
            return model.connection.isConfigured
                ? "Your threads travel with the account. The device bridge stays opt-in."
                : "Offline-ready chat stays useful even before you link the desktop."
        case .vault:
            return "Notes, files, and references stay close to the phone instead of disappearing into tabs."
        case .apps:
            return "Queue packs cleanly, keep install state visible, and send the good stuff back to your RoachNet box."
        case .runtime:
            return "RoachTail, RoachSync, account state, and the machine health all live in one readable shell."
        }
    }

    private var shellStatus: String {
        model.connection.isConfigured ? model.connection.securityLabel : "Offline ready"
    }

    private var shellSecondaryStatus: String {
        if let activeModelName = model.activeModelName, !activeModelName.isEmpty {
            return activeModelName
        }

        if model.runtime?.account?.linked == true {
            return "Account linked"
        }

        if model.queuedInstallCount > 0 {
            return "\(model.queuedInstallCount) queued"
        }

        return "Local-first"
    }

    var body: some View {
        ZStack {
            RoachBackdrop()

            RadialGradient(
                colors: [
                    shellAccent.opacity(0.18),
                    .clear,
                ],
                center: .topTrailing,
                startRadius: 16,
                endRadius: 280
            )
            .ignoresSafeArea()

            TabView(selection: $model.selectedTab) {
                ChatView(model: model)
                    .tag(CompanionTab.chat)

                VaultView(model: model)
                    .tag(CompanionTab.vault)

                AppsView(model: model)
                    .tag(CompanionTab.apps)

                RuntimeView(model: model)
                    .tag(CompanionTab.runtime)
            }
            .toolbar(.hidden, for: .tabBar)
            .animation(shellSpring, value: model.selectedTab)
            .safeAreaPadding(.bottom, 108)
        }
        .animation(shellSpring, value: model.selectedTab)
        .safeAreaInset(edge: .top, spacing: 0) {
            RoachShellDock(
                title: shellTitle,
                detail: shellDetail,
                accent: shellAccent,
                status: shellStatus,
                secondaryStatus: shellSecondaryStatus
            )
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 4)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            RoachFloatingTabBar(selection: $model.selectedTab, items: tabItems)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 10)
        }
        .task {
            if
                !didPresentInitialSettings &&
                !model.connection.isConfigured &&
                model.currentSession == nil &&
                model.runtime == nil
            {
                didPresentInitialSettings = true
                model.settingsPresented = true
            }
            await model.bootstrapIfNeeded()
        }
        .sheet(isPresented: Binding(
            get: { model.settingsPresented },
            set: { model.settingsPresented = $0 }
        )) {
            NavigationStack {
                ConnectionSettingsView(model: model)
            }
            .presentationDetents([.medium, .large])
        }
        .onOpenURL { url in
            model.handleIncomingURL(url)
        }
        .sensoryFeedback(.success, trigger: model.bannerText ?? "")
        .sensoryFeedback(.error, trigger: model.errorText ?? "")
    }
}
