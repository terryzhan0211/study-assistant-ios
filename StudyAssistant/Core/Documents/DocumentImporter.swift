import Foundation
import PDFKit
import Vision
import SwiftData

/// Copies a user-selected PDF into app storage, extracts text via PDFKit,
/// and falls back to Vision OCR for image-only pages.
@MainActor
@Observable
final class DocumentImporter {

    var isProcessing = false
    var progress: Double = 0        // 0.0 – 1.0
    var statusMessage = ""
    var lastError: String?

    // MARK: - Public

    func importPDF(from sourceURL: URL, context: ModelContext) async {
        isProcessing = true
        progress = 0
        statusMessage = "Copying file…"
        lastError = nil
        defer { isProcessing = false }

        // 1. Copy into the app's sandbox (off main thread for large files)
        let destURL: URL
        do {
            destURL = try await copyToAppStorage(sourceURL)
        } catch {
            lastError = error.localizedDescription
            return
        }

        // 2. Open with PDFKit
        guard let pdf = PDFDocument(url: destURL) else {
            lastError = "Could not open PDF"
            try? FileManager.default.removeItem(at: destURL)
            return
        }

        let pageCount = pdf.pageCount
        let attrs = try? FileManager.default.attributesOfItem(atPath: destURL.path(percentEncoded: false))
        let fileSize = (attrs?[.size] as? Int) ?? 0

        // 3. Persist the record immediately so the grid updates right away
        let doc = StudyDocument(
            title: sourceURL.deletingPathExtension().lastPathComponent,
            fileName: destURL.lastPathComponent
        )
        doc.pageCount = pageCount
        doc.fileSizeBytes = fileSize
        context.insert(doc)
        try? context.save()

        // 4. Extract text page by page
        var fullText = ""
        for i in 0..<pageCount {
            progress = Double(i) / Double(max(pageCount, 1)) * 0.9
            statusMessage = "Processing page \(i + 1) of \(pageCount)…"

            guard let page = pdf.page(at: i) else { continue }

            let pageText = page.string ?? ""
            if pageText.count > 20 {
                fullText += separator(fullText) + pageText
            } else {
                // Image-based page — use Vision OCR
                if let ocr = await ocrPage(page) {
                    fullText += separator(fullText) + ocr
                }
            }
        }

        doc.extractedText = fullText
        doc.isIndexed = !fullText.isEmpty
        progress = 1.0
        statusMessage = "Done"
        try? context.save()
    }

    // MARK: - Private helpers

    private func separator(_ existing: String) -> String {
        existing.isEmpty ? "" : "\n\n"
    }

    /// Copies the PDF to the app's sandbox on a background thread.
    private func copyToAppStorage(_ sourceURL: URL) async throws -> URL {
        try await Task.detached(priority: .userInitiated) {
            let fm = FileManager.default
            guard let base = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
                throw CocoaError(.fileNoSuchFile)
            }
            let pdfsDir = base.appendingPathComponent("pdfs", isDirectory: true)
            try fm.createDirectory(at: pdfsDir, withIntermediateDirectories: true)

            let uniqueName = UUID().uuidString + "_" + sourceURL.lastPathComponent
            let dest = pdfsDir.appendingPathComponent(uniqueName)

            _ = sourceURL.startAccessingSecurityScopedResource()
            defer { sourceURL.stopAccessingSecurityScopedResource() }

            try fm.copyItem(at: sourceURL, to: dest)
            return dest
        }.value
    }

    // MARK: - OCR pipeline

    /// Renders and OCR-processes one PDF page.
    /// PDFPage is not Sendable — rendering stays on @MainActor.
    /// Only the resulting CGImage (immutable, thread-safe) crosses to a background queue.
    private func ocrPage(_ page: PDFPage) async -> String? {
        let bounds = page.bounds(for: .mediaBox)
        guard let cgImage = renderPageSync(page, bounds: bounds) else { return nil }
        return await recognizeText(in: cgImage)
    }

    /// Synchronous render — must run on @MainActor because PDFPage is not Sendable.
    private func renderPageSync(_ page: PDFPage, bounds: CGRect) -> CGImage? {
        let scale: CGFloat = 1.5
        let w = Int(bounds.width * scale)
        let h = Int(bounds.height * scale)
        guard w > 0, h > 0 else { return nil }

        let cs = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil, width: w, height: h,
            bitsPerComponent: 8, bytesPerRow: 0, space: cs,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return nil }

        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        ctx.scaleBy(x: scale, y: scale)
        page.draw(with: .mediaBox, to: ctx)
        return ctx.makeImage()
    }

    /// Runs VNRecognizeTextRequest on a background queue so it doesn't block the main thread.
    /// `perform` is synchronous/blocking — always call it off-actor via DispatchQueue.
    private func recognizeText(in cgImage: CGImage) async -> String? {
        await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let req = VNRecognizeTextRequest { req, error in
                    guard error == nil else {
                        cont.resume(returning: nil)
                        return
                    }
                    let lines = (req.results as? [VNRecognizedTextObservation])?
                        .compactMap { $0.topCandidates(1).first?.string }
                        .joined(separator: "\n")
                    cont.resume(returning: lines?.isEmpty == false ? lines : nil)
                }
                req.recognitionLevel = .accurate
                req.usesLanguageCorrection = true
                do {
                    try VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([req])
                } catch {
                    // Must always resume — any uncaught throw here would hang the continuation
                    cont.resume(returning: nil)
                }
            }
        }
    }
}
