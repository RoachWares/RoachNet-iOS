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

    private var bottomAvoidance: CGFloat {
        RoachCompanionChrome.tabBarAvoidance
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

            selectedContent
                .id(model.selectedTab)
                .padding(.bottom, bottomAvoidance)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
                .animation(.spring(response: 0.36, dampingFraction: 0.86), value: model.selectedTab)
        }
        .overlay(alignment: .top) {
            RoachTopChromeScrim(accent: shellAccent)
        }
        .overlay(alignment: .bottom) {
            RoachBottomChromeScrim(accent: shellAccent)
                .frame(height: 86)
                .allowsHitTesting(false)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            RoachFloatingTabBar(selection: $model.selectedTab, items: tabItems)
                .padding(.horizontal, 16)
                .padding(.top, 2)
                .padding(.bottom, 2)
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
        .sensoryFeedback(.selection, trigger: model.selectedTab)
        .sensoryFeedback(.success, trigger: model.bannerText ?? "")
        .sensoryFeedback(.error, trigger: model.errorText ?? "")
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch model.selectedTab {
        case .chat:
            ChatView(model: model)
        case .vault:
            VaultView(model: model)
        case .apps:
            AppsView(model: model)
        case .runtime:
            RuntimeView(model: model)
        }
    }
}
