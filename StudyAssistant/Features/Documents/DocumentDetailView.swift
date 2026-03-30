import SwiftUI
import PDFKit
import SwiftData

struct DocumentDetailView: View {
    @Bindable var document: StudyDocument
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var rag = RAGEngine()

    var body: some View {
        ZStack {
            AdaptiveBackground(style: .document)

            VStack(spacing: 0) {
                Picker("View mode", selection: $selectedTab) {
                    Text("PDF").tag(0)
                    Text("Text").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppTheme.Spacing.md)
                .padding(.vertical, AppTheme.Spacing.sm)

                if selectedTab == 0 {
                    pdfSection
                } else {
                    textSection
                }
            }
        }
        .navigationTitle(document.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .task(id: document.id) {
            guard !document.isRAGIndexed, !document.extractedText.isEmpty else { return }
            await rag.index(
                text: document.extractedText,
                sourceType: "document",
                sourceID: document.id,
                sourceTitle: document.title,
                context: modelContext
            )
            document.isRAGIndexed = true
        }
    }

    // MARK: - PDF

    @ViewBuilder
    private var pdfSection: some View {
        if let url = document.resolvedURL, FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
            PDFKitView(url: url)
                .ignoresSafeArea(edges: .bottom)
        } else {
            fileUnavailableView
        }
    }

    // MARK: - Extracted text

    private var textSection: some View {
        ScrollView {
            GlassCard {
                if document.extractedText.isEmpty {
                    Text("No text could be extracted from this document.")
                        .font(.body)
                        .foregroundStyle(.primary.opacity(0.45))
                        .italic()
                } else {
                    Text(document.extractedText)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                }
            }
            .padding(AppTheme.Spacing.md)
            .padding(.bottom, AppTheme.Spacing.xl)
        }
    }

    // MARK: - File unavailable

    private var fileUnavailableView: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("File Not Found")
                .font(.title3.bold())
                .foregroundStyle(.primary)
            Text("The PDF may have been moved or deleted from the device.")
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.72))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppTheme.Spacing.xl)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                if let url = document.resolvedURL {
                    ShareLink(item: url, subject: Text(document.title)) {
                        Label("Share PDF", systemImage: "square.and.arrow.up")
                    }
                }
                Divider()
                Button(role: .destructive) {
                    deleteDocument()
                } label: {
                    Label("Delete Document", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    private func deleteDocument() {
        if let url = document.resolvedURL {
            try? FileManager.default.removeItem(at: url)
        }
        modelContext.delete(document)
        dismiss()
    }
}

// MARK: - PDFKit bridge

struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = .clear
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.documentURL != url {
            uiView.document = PDFDocument(url: url)
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: StudyDocument.self, configurations: config)
    let sample = StudyDocument(title: "Lecture 8 — Memory Management", fileName: "sample.pdf")
    sample.pageCount = 34
    sample.fileSizeBytes = 2_400_000
    sample.extractedText = "The heap is a region of memory used for dynamic allocation. malloc() and free() manage this space. Memory leaks occur when allocated blocks are never freed."
    container.mainContext.insert(sample)

    return NavigationStack {
        DocumentDetailView(document: sample)
    }
    .modelContainer(container)
    .environment(AppState())
}
