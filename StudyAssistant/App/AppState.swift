import SwiftUI

@MainActor
@Observable
final class AppState {
    var selectedTab: AppTab = .home

    // Populated as real data layers are built (Phase 3+)
    var sessionCount: Int = 0
    var documentCount: Int = 0

    // Phase 6: shared gateway config + AI service
    let gatewayConfig: GatewayConfig
    let ai: AIService

    init() {
        let config = GatewayConfig()
        gatewayConfig = config
        ai = AIService(gateway: config)
    }
}

enum AppTab: Hashable {
    case home, sessions, documents, chat, settings
}
