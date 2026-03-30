import Foundation
import SwiftData

@Model
final class RecordingSession {
    var id: UUID = UUID()
    var title: String
    var date: Date = Date()
    var durationSeconds: Int = 0
    var transcript: String = ""
    /// Set after WhisperKit post-processing pass (Phase 2 fallback)
    var correctedTranscript: String?
    /// Optional course tag for campus integration (Phase 7)
    var courseTag: String?
    /// True once this session's transcript has been chunked + embedded into TextChunk records.
    var isRAGIndexed: Bool = false

    init(title: String = "New Session") {
        self.title = title
    }

    // MARK: - Computed

    var wordCount: Int {
        let active = correctedTranscript ?? transcript
        return active
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .count
    }

    var formattedDuration: String {
        let h = durationSeconds / 3600
        let m = (durationSeconds % 3600) / 60
        let s = durationSeconds % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
