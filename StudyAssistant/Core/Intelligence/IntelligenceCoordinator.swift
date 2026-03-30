import Foundation
import FoundationModels

// MARK: - Routing types

enum IntelligenceMode {
    /// On-device Foundation Models (3B) — instant, private, $0 cost
    case local
    /// AWS LiteLLM gateway → GPT-4o / Gemini / Claude — for cloud fallback
    case cloud
    /// No AI available
    case unavailable
}

enum AITask {
    case summarize          // prefer local: fast + private
    case generateFlashcards // prefer local: structured output via @Generable
    case answerFromNotes    // prefer local: RAG-grounded Q&A
    case researchQuery      // prefer cloud: needs world knowledge
    case complexReasoning   // prefer cloud: multi-doc, long context
}

// MARK: - Coordinator

/// Routes AI tasks between the on-device Foundation Model and the cloud gateway.
@MainActor
@Observable
final class IntelligenceCoordinator {

    private let gatewayConfig: GatewayConfig

    init(gatewayConfig: GatewayConfig) {
        self.gatewayConfig = gatewayConfig
    }

    var localModelAvailable: Bool = false
    var isLocalModelLoading: Bool = false

    var cloudAvailable: Bool { gatewayConfig.isConfigured }

    // MARK: Routing

    func route(for task: AITask) -> IntelligenceMode {
        switch task {
        case .summarize, .generateFlashcards, .answerFromNotes:
            if localModelAvailable { return .local }
            if cloudAvailable      { return .cloud }
            return .unavailable
        case .researchQuery, .complexReasoning:
            if cloudAvailable      { return .cloud }
            if localModelAvailable { return .local }
            return .unavailable
        }
    }

    // MARK: Availability

    func checkLocalModelAvailability() async {
        isLocalModelLoading = true
        defer { isLocalModelLoading = false }
        localModelAvailable = SystemLanguageModel.isReallyAvailable
    }
}
