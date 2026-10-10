import SwiftUI

struct CompanionRootView: View {
    @State private var model = CompanionAppModel()
    @State private var didPresentInitialSettings = false
    @State private var tabBarMinY: CGFloat = .infinity
    @State private var keyboardVisible = false
    private var tabItems: [RoachTabBarItem] {
        [
            RoachTabBarItem(tab: .home, title: "Home", systemImage: "house", accent: RoachTheme.secondary),
            RoachTabBarItem(tab: .chat, title: "RoachClaw", systemImage: "message", accent: RoachTheme.primary),
            RoachTabBarItem(tab: .apps, title: "Apps", systemImage: "square.grid.2x2", accent: RoachTheme.tertiary),
            RoachTabBarItem(tab: .vault, title: "Vault", systemImage: "lock.rectangle", accent: RoachTheme.secondary),
            RoachTabBarItem(tab: .runtime, title: "Runtime", systemImage: "switch.2", accent: RoachTheme.cyan),
        ]
    }

    private var shellAccent: Color {
        switch model.selectedTab {
        case .home:
            return RoachTheme.secondary
        case .chat:
            return RoachTheme.primary
        case .vault:
            return RoachTheme.secondary
        case .apps:
            return RoachTheme.tertiary
        case .runtime:
            return RoachTheme.cyan
        }
    }

    private var bottomAvoidance: CGFloat {
        RoachCompanionChrome.tabBarAvoidance
    }

    var body: some View {
        ZStack {
            RoachBackdrop()

            selectedContent
                .environment(\.roachTabBarMinY, tabBarMinY)
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
            // The tab bar steps aside while the keyboard is up so the composer gets the room.
            if !keyboardVisible {
                RoachFloatingTabBar(selection: $model.selectedTab, items: tabItems)
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { minY in
                        tabBarMinY = minY
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
                    .padding(.bottom, 2)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation(.easeOut(duration: 0.2)) {
                keyboardVisible = true
                tabBarMinY = .infinity
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation(.easeOut(duration: 0.2)) { keyboardVisible = false }
        }
        .task {
            if
                !CompanionLaunchOptions.forceDemoMode &&
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
        .sheet(isPresented: Binding(
            get: { model.orgPresented },
            set: { model.orgPresented = $0 }
        )) {
            NavigationStack {
                OrgView(model: model)
            }
            .presentationDetents([.large])
        }
        .overlay(alignment: .bottom) {
            if let banner = model.bannerText, !banner.isEmpty, model.selectedTab == .home {
                RoachToast(title: banner, detail: nil, accent: RoachTheme.secondary) { model.bannerText = nil }
                    .task(id: banner) {
                        try? await Task.sleep(for: .seconds(5))
                        if model.bannerText == banner { model.bannerText = nil }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 92)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .accessibilityIdentifier("toast.banner")
            }
        }
        .font(RoachType.body)
        .foregroundStyle(RoachTheme.text)
        .tint(RoachTheme.purpleInk)
        .onOpenURL { url in
            model.handleIncomingURL(url)
        }
        .alert(
            model.pendingDeepLink?.title ?? "",
            isPresented: Binding(
                get: { model.pendingDeepLink != nil },
                set: { if !$0 { model.dismissPendingDeepLink() } }
            ),
            presenting: model.pendingDeepLink
        ) { pending in
            Button(pending.confirmLabel) { model.confirmPendingDeepLink() }
                .accessibilityIdentifier("deeplink.confirm")
            Button("Cancel", role: .cancel) { model.dismissPendingDeepLink() }
        } message: { pending in
            Text(pending.message)
        }
        .sensoryFeedback(.selection, trigger: model.selectedTab)
        .sensoryFeedback(.success, trigger: model.bannerText ?? "")
        .sensoryFeedback(.error, trigger: model.errorText ?? "")
    }

    @ViewBuilder
    private var selectedContent: some View {
        switch model.selectedTab {
        case .home:
            HomeView(model: model)
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
