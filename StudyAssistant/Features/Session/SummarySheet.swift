import SwiftUI

/// Streams a summary of a transcript and renders it as it arrives.
struct SummarySheet: View {
    let transcript: String
    @Environment(\.dismiss) private var dismiss

    @Environment(AppState.self) private var appState
    @State private var text = ""
    @State private var isStreaming = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                AdaptiveBackground(style: .chat)

                ScrollView {
                    Group {
                        if let error = errorMessage {
                            errorView(error)
                        } else if text.isEmpty && !isStreaming {
                            loadingView
                        } else {
                            GlassCard {
                                StreamingText(fullText: text)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(AppTheme.Spacing.md)
                        }
                    }
                    .padding(.bottom, AppTheme.Spacing.xl)
                }
            }
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if !text.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        ShareLink(item: text) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .task { await stream() }
        }
    }

    // MARK: - Sub-views

    private var loadingView: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ProgressView()
                .controlSize(.large)
            Text("Generating summary…")
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.72))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 80)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.82))
                .multilineTextAlignment(.center)
            Button("Try Again") {
                errorMessage = nil
                text = ""
                Task { await stream() }
            }
            .prominentButton(tint: .orange)
        }
        .padding(AppTheme.Spacing.xl)
    }

    // MARK: - Streaming

    private func stream() async {
        guard !transcript.isEmpty else {
            errorMessage = "No transcript to summarize."
            return
        }
        isStreaming = true
        defer { isStreaming = false }
        do {
            for try await chunk in appState.ai.summarize(transcript: transcript) {
                text = chunk
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    SummarySheet(transcript: "Today we covered the CAP theorem. A distributed system can only guarantee two of the three properties: Consistency, Availability, and Partition tolerance.")
        .environment(AppState())
}
