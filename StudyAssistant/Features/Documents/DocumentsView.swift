import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DocumentsView: View {
    @Query(sort: \StudyDocument.addedDate, order: .reverse)
    private var documents: [StudyDocument]

    @Environment(\.modelContext) private var modelContext

    @State private var importer = DocumentImporter()
    @State private var showFilePicker = false
    @State private var showErrorAlert = false

    private let columns = [GridItem(.adaptive(minimum: 160), spacing: AppTheme.Spacing.sm)]

    var body: some View {
        NavigationStack {
            ZStack {
                AdaptiveBackground(style: .document)

                Group {
                    if documents.isEmpty && !importer.isProcessing {
                        emptyState
                    } else {
                        documentGrid
                    }
                }

                // Processing overlay
                if importer.isProcessing {
                    importProgressOverlay
                }
            }
            .navigationTitle("Documents")
            .navigationDestination(for: StudyDocument.self) { doc in
                DocumentDetailView(document: doc)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showFilePicker = true } label: {
                        Image(systemName: "doc.badge.plus")
                    }
                    .glassButton(tint: .primary)
                    .disabled(importer.isProcessing)
                }
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [UTType.pdf],
                allowsMultipleSelection: false
            ) { result in
                handleFileSelection(result)
            }
            .alert("Import Failed", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { importer.lastError = nil }
            } message: {
                Text(importer.lastError ?? "An unknown error occurred.")
            }
            .onChange(of: importer.lastError) { _, error in
                showErrorAlert = error != nil
            }
        }
    }

    // MARK: - Grid

    private var documentGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: AppTheme.Spacing.sm) {
                ForEach(documents) { doc in
                    NavigationLink(value: doc) {
                        DocumentCard(document: doc)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(AppTheme.Spacing.md)
            .padding(.bottom, AppTheme.Spacing.xl)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 56))
                .foregroundStyle(.primary.opacity(0.65))
            Text("No Documents")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            Text("Import lecture slides or handouts to enable offline AI search.")
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.82))
                .multilineTextAlignment(.center)
            Button("Import PDF") { showFilePicker = true }
                .prominentButton(tint: .blue)
                .padding(.top, AppTheme.Spacing.sm)
        }
        .padding(AppTheme.Spacing.xl)
    }

    // MARK: - Import progress

    private var importProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.35)
                .ignoresSafeArea()

            GlassCard(cornerRadius: AppTheme.Radius.xl, padding: AppTheme.Spacing.lg) {
                VStack(spacing: AppTheme.Spacing.md) {
                    ProgressView(value: importer.progress)
                        .progressViewStyle(.linear)
                        .tint(.blue)

                    Text(importer.statusMessage)
                        .font(.subheadline)
                        .foregroundStyle(.primary.opacity(0.82))
                }
            }
            .padding(.horizontal, AppTheme.Spacing.xl)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.2), value: importer.isProcessing)
    }

    // MARK: - File selection handler

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                await importer.importPDF(from: url, context: modelContext)
            }
        case .failure(let error):
            importer.lastError = error.localizedDescription
        }
    }
}

// MARK: - Document card

private struct DocumentCard: View {
    let document: StudyDocument

    var body: some View {
        GlassCard(cornerRadius: AppTheme.Radius.lg, padding: AppTheme.Spacing.sm) {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: "doc.richtext.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(Color(red: 0.52, green: 0.72, blue: 0.96))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, AppTheme.Spacing.sm)

                    if document.isIndexed {
                        Image(systemName: "brain.fill")
                            .font(.caption2)
                            .foregroundStyle(.green)
                            .padding(4)
                            .background(Circle().glassEffect(in: Circle()))
                    }
                }

                Text(document.title)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack {
                    Text("\(document.pageCount)p")
                        .font(.caption2)
                        .foregroundStyle(.primary.opacity(0.72))
                    Spacer()
                    Text(document.formattedSize)
                        .font(.caption2)
                        .foregroundStyle(.primary.opacity(0.60))
                }
            }
        }
    }
}

#Preview {
    DocumentsView()
        .modelContainer(for: StudyDocument.self, inMemory: true)
        .environment(AppState())
}
