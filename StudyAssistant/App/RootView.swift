import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        TabView(selection: $appState.selectedTab) {
            Tab("Home", systemImage: "house.fill", value: AppTab.home) {
                HomeView()
            }
            Tab("Sessions", systemImage: "mic.fill", value: AppTab.sessions) {
                SessionListView()
            }
            Tab("Documents", systemImage: "doc.fill", value: AppTab.documents) {
                DocumentsView()
            }
            Tab("Chat", systemImage: "bubble.left.and.bubble.right.fill", value: AppTab.chat) {
                ChatView()
            }
            Tab("Settings", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView()
            }
        }
    }
}

#Preview {
    RootView()
        .environment(AppState())
}
