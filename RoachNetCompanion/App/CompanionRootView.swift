import SwiftUI

struct CompanionRootView: View {
    @State private var model = CompanionAppModel()
    @State private var didPresentInitialSettings = false

    var body: some View {
        ZStack {
            RoachBackdrop()

            TabView(selection: $model.selectedTab) {
                ChatView(model: model)
                    .tag(CompanionTab.chat)
                    .tabItem {
                        Label("Chat", systemImage: "message.fill")
                    }

                VaultView(model: model)
                    .tag(CompanionTab.vault)
                    .tabItem {
                        Label("Vault", systemImage: "archivebox.fill")
                    }

                AppsView(model: model)
                    .tag(CompanionTab.apps)
                    .tabItem {
                        Label("Apps", systemImage: "square.grid.2x2.fill")
                    }

                RuntimeView(model: model)
                    .tag(CompanionTab.runtime)
                    .tabItem {
                        Label("Runtime", systemImage: "switch.2")
                    }
            }
            .tint(RoachTheme.primary)
            .toolbarBackground(.visible, for: .tabBar)
            .toolbarBackground(RoachTheme.surface.opacity(0.96), for: .tabBar)
        }
        .task {
            if !didPresentInitialSettings && !model.connection.isConfigured {
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
        .sensoryFeedback(.success, trigger: model.bannerText ?? "")
        .sensoryFeedback(.error, trigger: model.errorText ?? "")
    }
}
