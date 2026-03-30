import Foundation
import SwiftData
import NaturalLanguage

// MARK: - Retrieved chunk (used by callers)

struct RetrievedChunk {
    let text: String
    let sourceTitle: String
    let sourceType: String
    let similarity: Float
}

// MARK: - RAG Engine

/// Orchestrates the full retrieval-augmented generation pipeline:
///   index  → chunk text → embed → persist TextChunk records
///   query  → embed → cosine rank → top-K → build grounded prompt
@MainActor
@Observable
final class RAGEngine {

    var isIndexing = false

    private let chunker = TextChunker()
    private let embedder = EmbeddingService()

    // MARK: - Indexing

    /// Chunks and embeds `text`, persisting `TextChunk` records into SwiftData.
    /// Deletes any existing chunks for the same `sourceID` first (re-index safe).
    func index(
        text: String,
        sourceType: String,
        sourceID: UUID,
        sourceTitle: String,
        context: ModelContext
    ) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isIndexing = true
        defer { isIndexing = false }

        // Remove stale chunks for this source
        deleteChunks(for: sourceID, context: context)

        let chunks = chunker.chunk(text)

        for (i, chunkText) in chunks.enumerated() {
            // Embed off main actor
            let vector = await embedder.embed(chunkText)

            let embeddingData: Data
            if let v = vector {
                embeddingData = v.asData
            } else {
                // Embedding unavailable — store empty data; keyword fallback handles it
                embeddingData = Data()
            }

            let chunk = TextChunk(
                text: chunkText,
                embeddingData: embeddingData,
                sourceType: sourceType,
                sourceID: sourceID,
                sourceTitle: sourceTitle,
                chunkIndex: i
            )
            context.insert(chunk)
        }

        try? context.save()
    }

    /// Deletes all TextChunk records belonging to a given source.
    func deleteChunks(for sourceID: UUID, context: ModelContext) {
        let id = sourceID
        let descriptor = FetchDescriptor<TextChunk>(
            predicate: #Predicate { $0.sourceID == id }
        )
        if let existing = try? context.fetch(descriptor) {
            existing.forEach { context.delete($0) }
        }
    }

    // MARK: - Retrieval

    /// Returns the top-K most relevant chunks for `query`.
    /// Uses cosine similarity when embeddings are available, keyword overlap otherwise.
    func retrieve(query: String, context: ModelContext, topK: Int = 4) async -> [RetrievedChunk] {
        let descriptor = FetchDescriptor<TextChunk>()
        guard let all = try? context.fetch(descriptor), !all.isEmpty else { return [] }

        // Attempt semantic search
        if let queryVec = await embedder.embed(query), !queryVec.isEmpty {
            let scored = all
                .filter { !$0.embeddingData.isEmpty }
                .map { ($0, $0.similarity(to: queryVec)) }
                .sorted { $0.1 > $1.1 }
                .prefix(topK)

            if !scored.isEmpty {
                return scored.map {
                    RetrievedChunk(
                        text: $0.0.text,
                        sourceTitle: $0.0.sourceTitle,
                        sourceType: $0.0.sourceType,
                        similarity: $0.1
                    )
                }
            }
        }

        // Fallback: keyword overlap
        return keywordRetrieve(query: query, chunks: all, topK: topK)
    }

    /// Retrieves relevant chunks and formats them as a grounded system context.
    /// Returns an empty string if no chunks are indexed yet.
    func groundedPrompt(for query: String, context: ModelContext) async -> String {
        let results = await retrieve(query: query, context: context)
        guard !results.isEmpty else { return query }

        let contextBlock = results
            .enumerated()
            .map { i, r in "[\(r.sourceTitle)]\n\(r.text)" }
            .joined(separator: "\n\n---\n\n")

        return """
        You are a study assistant. Answer using ONLY the following notes from the student's \
        own lectures and documents. If the answer is not in the notes, say so clearly.

        === NOTES ===
        \(contextBlock)
        === END NOTES ===

        Question: \(query)
        """
    }

    // MARK: - Keyword fallback

    private func keywordRetrieve(query: String, chunks: [TextChunk], topK: Int) -> [RetrievedChunk] {
        let queryWords = Set(
            query.lowercased()
                .components(separatedBy: .whitespacesAndNewlines)
                .filter { $0.count > 2 }  // skip stopwords heuristic
        )
        return chunks
            .map { chunk -> (TextChunk, Int) in
                let chunkWords = Set(chunk.text.lowercased().components(separatedBy: .whitespacesAndNewlines))
                return (chunk, chunkWords.intersection(queryWords).count)
            }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(topK)
            .map { RetrievedChunk(text: $0.0.text, sourceTitle: $0.0.sourceTitle, sourceType: $0.0.sourceType, similarity: Float($0.1)) }
    }
}
