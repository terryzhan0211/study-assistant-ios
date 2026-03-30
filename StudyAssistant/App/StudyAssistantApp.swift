import SwiftUI
import SwiftData

@main
struct StudyAssistantApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
        }
        .modelContainer(for: [RecordingSession.self, StudyDocument.self, TextChunk.self])
    }
}
