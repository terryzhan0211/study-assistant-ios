import SwiftUI
import SwiftData

struct SessionListView: View {
    @Query(sort: \RecordingSession.date, order: .reverse)
    private var sessions: [RecordingSession]

    @Environment(\.modelContext) private var modelContext
    @State private var showRecording = false

    var body: some View {
        NavigationStack {
            ZStack {
                AdaptiveBackground(style: .session)

                Group {
                    if sessions.isEmpty { emptyState } else { sessionList }
                }
            }
            .navigationTitle("Sessions")
            .navigationDestination(for: RecordingSession.self) { session in
                SessionDetailView(session: session)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { showRecording = true } label: {
                        Image(systemName: "mic.badge.plus")
                    }
                    .glassButton(tint: .primary)
                }
            }
            .sheet(isPresented: $showRecording) {
                RecordingView()
            }
        }
    }

    // MARK: List

    private var sessionList: some View {
        ScrollView {
            LazyVStack(spacing: AppTheme.Spacing.sm) {
                ForEach(sessions) { session in
                    NavigationLink(value: session) {
                        SessionRow(session: session)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(AppTheme.Spacing.md)
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "mic.slash.fill")
                .font(.system(size: 56))
                .foregroundStyle(.primary.opacity(0.65))
            Text("No Sessions Yet")
                .font(.title2.bold())
                .foregroundStyle(.primary)
            Text("Tap the mic button to record your first lecture.")
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.82))
                .multilineTextAlignment(.center)
            Button("Start Recording") { showRecording = true }
                .prominentButton(tint: .orange)
                .padding(.top, AppTheme.Spacing.sm)
        }
        .padding(AppTheme.Spacing.xl)
    }
}

// MARK: - Session row

private struct SessionRow: View {
    let session: RecordingSession

    var body: some View {
        GlassCard {
            HStack(spacing: AppTheme.Spacing.md) {
                Image(systemName: "waveform.badge.checkmark")
                    .font(.title2)
                    .foregroundStyle(.orange)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(session.title)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(session.date, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.primary.opacity(0.80))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(session.formattedDuration)
                        .font(.caption.bold())
                        .foregroundStyle(.primary.opacity(0.92))
                    Text("\(session.wordCount) words")
                        .font(.caption2)
                        .foregroundStyle(.primary.opacity(0.72))
                }

                Image(systemName: "chevron.right")
                    .font(.caption2.bold())
                    .foregroundStyle(.primary.opacity(0.35))
            }
        }
    }
}

#Preview {
    SessionListView()
        .modelContainer(for: RecordingSession.self, inMemory: true)
        .environment(AppState())
}
