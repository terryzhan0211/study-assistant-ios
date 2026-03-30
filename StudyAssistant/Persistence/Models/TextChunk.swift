import Foundation
import SwiftData
import Accelerate

@Model
final class TextChunk {
    var id: UUID = UUID()
    /// The raw text of this chunk (~200 words).
    var text: String
    /// Serialised [Float] embedding vector from NLEmbedding.sentenceEmbedding.
    var embeddingData: Data
    /// "session" or "document"
    var sourceType: String
    /// ID of the parent RecordingSession or StudyDocument.
    var sourceID: UUID
    /// Human-readable title shown in search results.
    var sourceTitle: String
    /// Position within the source (for ordering in context).
    var chunkIndex: Int
    var addedDate: Date = Date()

    init(
        text: String,
        embeddingData: Data,
        sourceType: String,
        sourceID: UUID,
        sourceTitle: String,
        chunkIndex: Int
    ) {
        self.text = text
        self.embeddingData = embeddingData
        self.sourceType = sourceType
        self.sourceID = sourceID
        self.sourceTitle = sourceTitle
        self.chunkIndex = chunkIndex
    }

    // MARK: - Vector helpers

    var embedding: [Float] {
        embeddingData.withUnsafeBytes { Array($0.bindMemory(to: Float.self)) }
    }

    /// Cosine similarity in [−1, 1]. Uses Accelerate for performance.
    func similarity(to query: [Float]) -> Float {
        let a = embedding
        let b = query
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0
        var magA: Float = 0
        var magB: Float = 0
        vDSP_dotpr(a, 1, b, 1, &dot, vDSP_Length(a.count))
        vDSP_svesq(a, 1, &magA, vDSP_Length(a.count))
        vDSP_svesq(b, 1, &magB, vDSP_Length(b.count))
        guard magA > 0, magB > 0 else { return 0 }
        return dot / (sqrt(magA) * sqrt(magB))
    }
}

// MARK: - [Float] ↔ Data

extension [Float] {
    var asData: Data { withUnsafeBytes { Data($0) } }
}
