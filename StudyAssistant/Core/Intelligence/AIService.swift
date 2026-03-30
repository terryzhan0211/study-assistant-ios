import Foundation
import FoundationModels

/// Thin wrapper around `LanguageModelSession` + `CloudGatewayClient`.
///
/// Routing:
///   1. If on-device Foundation Models is available → use it (private, free).
///   2. If not, and cloud gateway is configured → stream from LiteLLM gateway.
///   3. Otherwise → throw `AIError.modelUnavailable`.
@MainActor
@Observable
final class AIService {

    // MARK: - Dependencies

    private let gateway: GatewayConfig

    init(gateway: GatewayConfig) {
        self.gateway = gateway
    }

    // MARK: - Chat session (on-device, persists across turns)

    private var chatSession: LanguageModelSession?

    // MARK: - Cloud client (lazy, recreated when config changes)

    private var _cloudClient: CloudGatewayClient?

    private var cloudClient: CloudGatewayClient? {
        guard gateway.isConfigured else { return nil }
        if let existing = _cloudClient { return existing }
        let client = CloudGatewayClient(
            baseURL: gateway.baseURL,
            apiKey:  gateway.apiKey,
            model:   gateway.model
        )
        _cloudClient = client
        return client
    }

    // Invalidate cached client whenever settings change
    func invalidateCloudClient() { _cloudClient = nil }

    // MARK: - Availability

    var isLocalAvailable: Bool { SystemLanguageModel.isReallyAvailable }

    var isAnyAvailable: Bool { isLocalAvailable || gateway.isConfigured }

    // MARK: - Summarise

    func summarize(transcript: String) -> AsyncThrowingStream<String, Error> {
        if isLocalAvailable {
            return localSummarize(transcript: transcript)
        }
        return cloudSummarize(transcript: transcript)
    }

    // MARK: - Flashcards

    func generateFlashcards(from transcript: String) async throws -> FlashcardDeck {
        if isLocalAvailable {
            return try await localFlashcards(from: transcript)
        }
        // Cloud path: ask for JSON, parse manually
        return try await cloudFlashcards(from: transcript)
    }

    // MARK: - Quiz

    func generateQuiz(from transcript: String) async throws -> QuizSet {
        if isLocalAvailable {
            return try await localQuiz(from: transcript)
        }
        return try await cloudQuiz(from: transcript)
    }

    // MARK: - Chat

    func chat(message: String) -> AsyncThrowingStream<String, Error> {
        if isLocalAvailable {
            return localChat(message: message)
        }
        return cloudChat(message: message)
    }

    func resetChat() { chatSession = nil }

    // MARK: - Error mapping

    private static func mapError(_ error: Error) -> Error {
        let ns = error as NSError
        if ns.domain.contains("FoundationModels") || ns.domain.contains("GenerationError") {
            return AIError.modelUnavailable
        }
        return error
    }
}

// MARK: - Local (Foundation Models) implementations

private extension AIService {

    func localSummarize(transcript: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { cont in
            let task = Task {
                let session = LanguageModelSession(
                    instructions: "You are a concise academic summarizer. Produce clear, well-structured bullet-point summaries of lecture transcripts."
                )
                let prompt = """
                Summarize the following lecture transcript in 5–7 concise bullet points. \
                Focus on key concepts, definitions, and takeaways. Use "•" for bullets.

                Transcript:
                \(transcript.prefix(4000))
                """
                do {
                    for try await partial in session.streamResponse(to: prompt) {
                        cont.yield(partial.content)
                    }
                    cont.finish()
                } catch {
                    cont.finish(throwing: Self.mapError(error))
                }
            }
            cont.onTermination = { _ in task.cancel() }
        }
    }

    func localFlashcards(from transcript: String) async throws -> FlashcardDeck {
        let session = LanguageModelSession(
            instructions: "You generate study flashcards from lecture content. Be concise and accurate."
        )
        let prompt = """
        Create a set of 6–8 flashcards from the following lecture transcript. \
        Each card should test one key concept, term, or fact.

        Transcript:
        \(transcript.prefix(4000))
        """
        do {
            let response = try await session.respond(to: prompt, generating: FlashcardDeck.self)
            return response.content
        } catch {
            throw Self.mapError(error)
        }
    }

    func localQuiz(from transcript: String) async throws -> QuizSet {
        let session = LanguageModelSession(
            instructions: "You generate multiple-choice quiz questions to test student understanding of lectures."
        )
        let prompt = """
        Create 5 multiple-choice questions based on the following lecture transcript. \
        Each question should have exactly 4 choices. Vary difficulty from recall to application.

        Transcript:
        \(transcript.prefix(4000))
        """
        do {
            let response = try await session.respond(to: prompt, generating: QuizSet.self)
            return response.content
        } catch {
            throw Self.mapError(error)
        }
    }

    func localChat(message: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { cont in
            let task = Task {
                if self.chatSession == nil {
                    self.chatSession = LanguageModelSession(
                        instructions: "You are a helpful study assistant. Answer questions about lecture notes and study materials concisely and accurately."
                    )
                }
                guard let session = self.chatSession else {
                    cont.finish(throwing: AIError.modelUnavailable)
                    return
                }
                do {
                    for try await partial in session.streamResponse(to: message) {
                        cont.yield(partial.content)
                    }
                    cont.finish()
                } catch {
                    cont.finish(throwing: Self.mapError(error))
                }
            }
            cont.onTermination = { _ in task.cancel() }
        }
    }
}

// MARK: - Cloud (LiteLLM gateway) implementations

private extension AIService {

    private func requireCloud() throws -> CloudGatewayClient {
        guard let client = cloudClient else { throw AIError.modelUnavailable }
        return client
    }

    func cloudSummarize(transcript: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { cont in
            let task = Task {
                guard let client = self.cloudClient else {
                    cont.finish(throwing: AIError.modelUnavailable)
                    return
                }
                let messages: [(role: String, content: String)] = [
                    ("system", "You are a concise academic summarizer. Produce clear, well-structured bullet-point summaries of lecture transcripts."),
                    ("user",   "Summarize the following lecture transcript in 5–7 concise bullet points. Focus on key concepts, definitions, and takeaways. Use \"•\" for bullets.\n\nTranscript:\n\(transcript.prefix(4000))")
                ]
                do {
                    for try await chunk in client.chatStream(messages: messages) {
                        cont.yield(chunk)
                    }
                    cont.finish()
                } catch {
                    cont.finish(throwing: error)
                }
            }
            cont.onTermination = { _ in task.cancel() }
        }
    }

    func cloudFlashcards(from transcript: String) async throws -> FlashcardDeck {
        let client = try requireCloud()
        let messages: [(role: String, content: String)] = [
            ("system", "You generate study flashcards from lecture content. Respond ONLY with valid JSON in this exact format: {\"cards\":[{\"front\":\"...\",\"back\":\"...\"}]}"),
            ("user",   "Create 6–8 flashcards from this transcript:\n\n\(transcript.prefix(4000))")
        ]
        let json = try await client.chat(messages: messages, maxTokens: 2048)
        return try parseCloudFlashcards(json)
    }

    func cloudQuiz(from transcript: String) async throws -> QuizSet {
        let client = try requireCloud()
        let messages: [(role: String, content: String)] = [
            ("system", "You create multiple-choice quiz questions. Respond ONLY with valid JSON: {\"questions\":[{\"question\":\"...\",\"choices\":[\"A\",\"B\",\"C\",\"D\"],\"correctIndex\":0,\"explanation\":\"...\"}]}"),
            ("user",   "Create 5 quiz questions from this transcript:\n\n\(transcript.prefix(4000))")
        ]
        let json = try await client.chat(messages: messages, maxTokens: 2048)
        return try parseCloudQuiz(json)
    }

    func cloudChat(message: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { cont in
            let task = Task {
                guard let client = self.cloudClient else {
                    cont.finish(throwing: AIError.modelUnavailable)
                    return
                }
                let messages: [(role: String, content: String)] = [
                    ("system", "You are a helpful study assistant. Answer questions about lecture notes and study materials concisely and accurately."),
                    ("user", message)
                ]
                do {
                    for try await chunk in client.chatStream(messages: messages) {
                        cont.yield(chunk)
                    }
                    cont.finish()
                } catch {
                    cont.finish(throwing: error)
                }
            }
            cont.onTermination = { _ in task.cancel() }
        }
    }

    // MARK: Cloud JSON parsers

    private func parseCloudFlashcards(_ json: String) throws -> FlashcardDeck {
        // Extract JSON block if model wrapped it in markdown
        let cleaned = extractJSON(from: json)
        guard let data = cleaned.data(using: .utf8) else { throw AIError.parseError }

        struct Wrapper: Decodable {
            struct Card: Decodable { let front, back: String }
            let title: String?
            let cards: [Card]
        }
        let wrapper = try JSONDecoder().decode(Wrapper.self, from: data)
        let cards = wrapper.cards.map { Flashcard(front: $0.front, back: $0.back) }
        guard !cards.isEmpty else { throw AIError.parseError }
        return FlashcardDeck(title: wrapper.title ?? "Flashcards", cards: cards)
    }

    private func parseCloudQuiz(_ json: String) throws -> QuizSet {
        let cleaned = extractJSON(from: json)
        guard let data = cleaned.data(using: .utf8) else { throw AIError.parseError }

        struct Wrapper: Decodable {
            struct Q: Decodable {
                let question: String
                let choices: [String]
                let correctIndex: Int
                let explanation: String
            }
            let questions: [Q]
        }
        let wrapper = try JSONDecoder().decode(Wrapper.self, from: data)
        let questions = wrapper.questions.compactMap { q -> QuizQuestion? in
            guard q.correctIndex >= 0, q.correctIndex < q.choices.count else { return nil }
            return QuizQuestion(
                question: q.question,
                choices: q.choices,
                correctAnswer: q.choices[q.correctIndex],
                explanation: q.explanation
            )
        }
        guard !questions.isEmpty else { throw AIError.parseError }
        return QuizSet(questions: questions)
    }

    private func extractJSON(from text: String) -> String {
        // Strip markdown code fences if present
        if let start = text.range(of: "{"), let end = text.range(of: "}", options: .backwards) {
            return String(text[start.lowerBound...end.upperBound])
        }
        return text
    }
}

// MARK: - SystemLanguageModel availability

extension SystemLanguageModel {
    /// True only when Foundation Models can actually run on this device.
    /// `availability` reports `.available` on the simulator because the framework
    /// is linked, but generation always fails with GenerationError -1. This
    /// property returns `false` on simulator unconditionally.
    static var isReallyAvailable: Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
        #endif
    }
}

// MARK: - Errors

enum AIError: LocalizedError {
    case modelUnavailable
    case parseError

    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return "No AI available. Enable Apple Intelligence in Settings, or configure a Cloud Gateway in Settings → Intelligence."
        case .parseError:
            return "Could not parse AI response. Please try again."
        }
    }
}
