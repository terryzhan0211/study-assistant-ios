import Foundation
import SwiftData

@Model
final class StudyDocument {
    var id: UUID = UUID()
    var title: String
    /// Unique filename stored under <app-documents>/pdfs/
    var fileName: String
    var pageCount: Int = 0
    var extractedText: String = ""
    /// true once Vision OCR / PDFKit extraction succeeded
    var isIndexed: Bool = false
    /// Optional course tag (Phase 7)
    var courseTag: String?
    var addedDate: Date = Date()
    /// True once this document's extractedText has been chunked + embedded into TextChunk records.
    var isRAGIndexed: Bool = false
    var fileSizeBytes: Int = 0

    init(title: String, fileName: String) {
        self.title = title
        self.fileName = fileName
    }

    // MARK: - Computed

    /// Full path inside the app sandbox — valid across launches.
    var resolvedURL: URL? {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("pdfs", isDirectory: true)
            .appendingPathComponent(fileName)
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSizeBytes), countStyle: .file)
    }
}
