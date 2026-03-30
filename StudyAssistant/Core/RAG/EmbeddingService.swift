import Foundation
import NaturalLanguage

/// Off-main-thread embedding using NLEmbedding.sentenceEmbedding.
///
/// `actor` isolation guarantees the NLEmbedding model (which is not thread-safe)
/// is accessed from one thread at a time without blocking the main actor.
actor EmbeddingService {

    private let model: NLEmbedding?

    init() {
        model = NLEmbedding.sentenceEmbedding(for: .english)
    }

    var isAvailable: Bool { model != nil }

    /// Embeds a single string. Returns nil if the model is unavailable or the
    /// text produces no vector (e.g. pure punctuation / whitespace).
    func embed(_ text: String) -> [Float]? {
        guard let model else { return nil }
        guard let vector = model.vector(for: text) else { return nil }
        return vector.map { Float($0) }
    }

    /// Embeds a batch of strings. Nil entries indicate embedding failure.
    func embed(_ texts: [String]) -> [[Float]?] {
        texts.map { embed($0) }
    }
}
