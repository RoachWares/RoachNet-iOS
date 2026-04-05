import SwiftUI

struct CompanionRootView: View {
    @State private var model = CompanionAppModel()
    @State private var didPresentInitialSettings = false

    var body: some View {
        ZStack {
            RoachBackdrop()

            TabView {
                ChatView(model: model)
                    .tabItem {
                        Label("Chat", systemImage: "message.fill")
                    }

                VaultView(model: model)
                    .tabItem {
                        Label("Vault", systemImage: "archivebox.fill")
                    }

                AppsView(model: model)
                    .tabItem {
                        Label("Apps", systemImage: "square.grid.2x2.fill")
                    }

                RuntimeView(model: model)
                    .tabItem {
                        Label("Runtime", systemImage: "switch.2")
                    }
            }
            .tint(RoachTheme.primary)
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
    }
}
