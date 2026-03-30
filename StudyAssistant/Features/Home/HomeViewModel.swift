import SwiftUI

@MainActor
@Observable
final class HomeViewModel {

    // Stats — wired to real data in Phase 3+
    var todaySessions: Int = 0
    var totalDocuments: Int = 0
    var totalTranscriptMinutes: Int = 0
    var aiModeLabel: String = "Cloud (setup required)"

    // Greeting
    var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        return switch hour {
        case 5..<12:  "Good morning"
        case 12..<17: "Good afternoon"
        default:      "Good evening"
        }
    }

    func onAppear(appState: AppState) async {
        let coordinator = IntelligenceCoordinator(gatewayConfig: appState.gatewayConfig)
        await coordinator.checkLocalModelAvailability()
        if coordinator.localModelAvailable {
            aiModeLabel = "Local — Apple Intelligence"
        } else if appState.gatewayConfig.isConfigured {
            aiModeLabel = "Cloud gateway"
        } else {
            aiModeLabel = "No AI configured"
        }
    }
}
