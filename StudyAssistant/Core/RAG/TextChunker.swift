import Foundation

/// Splits a body of text into overlapping word-window chunks suitable for embedding.
struct TextChunker {

    /// Target words per chunk.
    let chunkSize: Int
    /// Words shared between adjacent chunks (context continuity).
    let overlap: Int

    init(chunkSize: Int = 200, overlap: Int = 40) {
        self.chunkSize = chunkSize
        self.overlap = overlap
    }

    // MARK: - Public

    /// Returns an array of chunk strings. Minimum 1 chunk even for short inputs.
    func chunk(_ text: String) -> [String] {
        let words = tokenize(text)
        guard !words.isEmpty else { return [] }
        guard words.count > chunkSize else { return [words.joined(separator: " ")] }

        var chunks: [String] = []
        var start = 0

        while start < words.count {
            let end = min(start + chunkSize, words.count)
            let slice = words[start..<end].joined(separator: " ")
            chunks.append(slice)
            if end == words.count { break }
            start += chunkSize - overlap
        }

        return chunks
    }

    // MARK: - Private

    /// Splits on whitespace and strips punctuation-only tokens.
    private func tokenize(_ text: String) -> [String] {
        text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
    }
}
