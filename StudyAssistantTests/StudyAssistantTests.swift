import Testing
@testable import StudyAssistant

@Suite("IntelligenceCoordinator")
@MainActor
struct IntelligenceCoordinatorTests {

    @Test("Routes summarize task to local when model is available")
    func routesSummarizeToLocal() {
        let coordinator = IntelligenceCoordinator()
        coordinator.localModelAvailable = true
        #expect(coordinator.route(for: .summarize) == .local)
    }

    @Test("Routes research query to cloud regardless of local availability")
    func routesResearchToCloud() {
        let coordinator = IntelligenceCoordinator()
        coordinator.localModelAvailable = true
        #expect(coordinator.route(for: .researchQuery) == .cloud)
    }

    @Test("Falls back to cloud when local model unavailable")
    func fallsBackToCloud() {
        let coordinator = IntelligenceCoordinator()
        coordinator.localModelAvailable = false
        #expect(coordinator.route(for: .summarize) == .cloud)
        #expect(coordinator.route(for: .generateFlashcards) == .cloud)
        #expect(coordinator.route(for: .answerFromNotes) == .cloud)
    }
}
