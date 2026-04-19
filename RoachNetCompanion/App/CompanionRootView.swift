import SwiftUI

struct CompanionRootView: View {
    @State private var model = CompanionAppModel()
    @State private var didPresentInitialSettings = false
    private var tabItems: [RoachTabBarItem] {
        [
            RoachTabBarItem(tab: .chat, title: "RoachClaw", systemImage: "message.fill", accent: RoachTheme.primary),
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
            .safeAreaPadding(.bottom, 96)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            RoachFloatingTabBar(selection: $model.selectedTab, items: tabItems)
                .padding(.horizontal, 16)
                .padding(.top, 6)
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
