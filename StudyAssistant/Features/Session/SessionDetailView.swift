import SwiftUI
import SwiftData

struct SessionDetailView: View {
    @Bindable var session: RecordingSession
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showExportSheet = false
    @State private var exportText = ""
    @State private var showSummary = false
    @State private var showFlashcards = false
    @State private var showQuiz = false
    @State private var rag = RAGEngine()

    var body: some View {
        ZStack {
            AdaptiveBackground(style: .session)

            ScrollView {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    metaCard
                    aiActionsCard
                    transcriptCard
                }
                .padding(AppTheme.Spacing.md)
                .padding(.bottom, AppTheme.Spacing.xl)
            }
        }
        .navigationTitle(session.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .task(id: session.id) {
            guard !session.isRAGIndexed else { return }
            let text = session.correctedTranscript ?? session.transcript
            guard !text.isEmpty else { return }
            await rag.index(
                text: text,
                sourceType: "session",
                sourceID: session.id,
                sourceTitle: session.title,
                context: modelContext
            )
            session.isRAGIndexed = true
        }
        .sheet(isPresented: $showExportSheet) {
            exportSheet
        }
        .sheet(isPresented: $showSummary) {
            SummarySheet(transcript: session.correctedTranscript ?? session.transcript)
        }
        .sheet(isPresented: $showFlashcards) {
            FlashcardsView(transcript: session.correctedTranscript ?? session.transcript)
        }
        .sheet(isPresented: $showQuiz) {
            QuizView(transcript: session.correctedTranscript ?? session.transcript)
        }
    }

    // MARK: - Meta card

    private var metaCard: some View {
        GlassCard {
            HStack(spacing: AppTheme.Spacing.lg) {
                metaStat(value: session.formattedDuration, label: "Duration",  icon: "clock.fill",   tint: .orange)
                Divider().frame(height: 36).opacity(0.3)
                metaStat(value: "\(session.wordCount)",    label: "Words",     icon: "text.word.spacing", tint: .blue)
                Divider().frame(height: 36).opacity(0.3)
                metaStat(value: session.date.formatted(.dateTime.month(.abbreviated).day()),
                         label: "Date", icon: "calendar", tint: .purple)
            }
        }
    }

    private func metaStat(value: String, label: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).foregroundStyle(tint).font(.subheadline)
            Text(value).font(.subheadline.bold()).foregroundStyle(.primary)
            Text(label).font(.caption2).foregroundStyle(.primary.opacity(0.65))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - AI actions

    private var aiActionsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                Text("AI Actions")
                    .font(.caption.bold())
                    .foregroundStyle(.primary.opacity(0.65))

                HStack(spacing: AppTheme.Spacing.sm) {
                    AIActionChip(icon: "sparkles",            label: "Summarise") { showSummary    = true }
                    AIActionChip(icon: "rectangle.stack",     label: "Flashcards") { showFlashcards = true }
                    AIActionChip(icon: "questionmark.circle", label: "Quiz Me")   { showQuiz       = true }
                }
            }
        }
    }

    // MARK: - Transcript card

    private var transcriptCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                HStack {
                    Text("Transcript")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Spacer()
                    if session.correctedTranscript != nil {
                        Label("Corrected", systemImage: "waveform.badge.checkmark")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }

                Divider().opacity(0.3)

                let displayText = session.correctedTranscript ?? session.transcript
                if displayText.isEmpty {
                    Text("No transcript recorded.")
                        .font(.body)
                        .foregroundStyle(.primary.opacity(0.45))
                        .italic()
                } else {
                    Text(displayText)
                        .font(.body)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                Button {
                    exportText = buildExportText(format: .markdown)
                    showExportSheet = true
                } label: {
                    Label("Export as Markdown", systemImage: "doc.text")
                }
                Button {
                    exportText = buildExportText(format: .plain)
                    showExportSheet = true
                } label: {
                    Label("Export as Plain Text", systemImage: "doc.plaintext")
                }
                Divider()
                Button(role: .destructive) {
                    modelContext.delete(session)
                    dismiss()
                } label: {
                    Label("Delete Session", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
    }

    // MARK: - Export sheet

    private var exportSheet: some View {
        NavigationStack {
            ScrollView {
                Text(exportText)
                    .font(.body.monospaced())
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .padding(AppTheme.Spacing.md)
            }
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: exportText) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { showExportSheet = false }
                }
            }
        }
    }

    // MARK: - Export helpers

    enum ExportFormat { case markdown, plain }

    private func buildExportText(format: ExportFormat) -> String {
        let transcript = session.correctedTranscript ?? session.transcript
        switch format {
        case .markdown:
            return """
            # \(session.title)

            **Date:** \(session.date.formatted(date: .long, time: .shortened))
            **Duration:** \(session.formattedDuration)
            **Words:** \(session.wordCount)

            ---

            ## Transcript

            \(transcript)
            """
        case .plain:
            return """
            \(session.title)
            \(session.date.formatted(date: .long, time: .shortened))
            Duration: \(session.formattedDuration) · \(session.wordCount) words

            \(transcript)
            """
        }
    }
}

// MARK: - AI action chip

private struct AIActionChip: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(.purple)
                Text(label)
                    .font(.caption2.bold())
                    .foregroundStyle(.primary.opacity(0.80))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppTheme.Spacing.sm)
            .glassEffect(in: RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: RecordingSession.self, configurations: config)
    let sample = RecordingSession(title: "CS 401 — Distributed Systems")
    sample.transcript = "Today we covered the CAP theorem. A distributed system can only guarantee two of the three properties: Consistency, Availability, and Partition tolerance. Brewer's theorem states that in the presence of a network partition, one must choose between consistency and availability."
    sample.durationSeconds = 4530
    container.mainContext.insert(sample)

    return NavigationStack {
        SessionDetailView(session: sample)
    }
    .modelContainer(container)
    .environment(AppState())
}
