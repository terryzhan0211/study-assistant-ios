import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = HomeViewModel()
    @State private var showChatSheet = false
    @State private var showSessionSheet = false
    @State private var showDocumentsSheet = false

    @Query private var sessions: [RecordingSession]
    @Query private var documents: [StudyDocument]

    private var todaySessions: Int {
        let start = Calendar.current.startOfDay(for: .now)
        return sessions.filter { $0.date >= start }.count
    }

    private var totalTranscriptMinutes: Int {
        sessions.reduce(0) { $0 + $1.durationSeconds } / 60
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AdaptiveBackground(style: .study)

                ScrollView {
                    VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                        headerSection
                        statsRow
                        quickActionsSection
                        aiStatusCard
                    }
                    .padding(AppTheme.Spacing.md)
                    .padding(.bottom, AppTheme.Spacing.xl)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.onAppear(appState: appState) }
            .sheet(isPresented: $showChatSheet) {
                SheetWrapper(title: "AI Chat") { ChatView() }
            }
            .sheet(isPresented: $showSessionSheet) {
                RecordingView()   // Direct to recording, not the list
            }
            .sheet(isPresented: $showDocumentsSheet) {
                SheetWrapper(title: "Documents") { DocumentsView() }
            }
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
            Text(viewModel.greeting)
                .font(.title3)
                .foregroundStyle(.primary.opacity(0.90))
            Text("Study Assistant")
                .font(.largeTitle.bold())
                .foregroundStyle(.primary)
        }
        .padding(.top, AppTheme.Spacing.sm)
    }

    private var statsRow: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            StatCard(value: "\(todaySessions)",              label: "Sessions",    icon: "mic.fill",  tint: .orange)
            StatCard(value: "\(documents.count)",            label: "Documents",   icon: "doc.fill",  tint: .blue)
            StatCard(value: "\(totalTranscriptMinutes)m",   label: "Transcribed", icon: "waveform",  tint: .purple)
        }
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text("Quick Actions")
                .font(.headline)
                .foregroundStyle(.primary.opacity(0.92))

            HStack(spacing: AppTheme.Spacing.sm) {
                QuickActionButton(title: "Record",     icon: "mic.fill",       tint: .orange) { showSessionSheet   = true }
                QuickActionButton(title: "Import PDF", icon: "doc.badge.plus", tint: .blue)   { showDocumentsSheet = true }
                QuickActionButton(title: "Ask AI",     icon: "sparkles",       tint: .purple) { showChatSheet      = true }
            }
        }
    }

    private var aiStatusCard: some View {
        GlassCard {
            HStack(spacing: AppTheme.Spacing.sm) {
                Image(systemName: "cpu.fill")
                    .font(.title2)
                    .foregroundStyle(.primary.opacity(0.90))

                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Engine")
                        .font(.caption)
                        .foregroundStyle(.primary.opacity(0.80))
                    Text(viewModel.aiModeLabel)
                        .font(.subheadline.bold())
                        .foregroundStyle(.primary)
                }

                Spacer()

                Circle()
                    .fill(viewModel.aiModeLabel.contains("Local") ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
            }
        }
    }
}

// MARK: - Sub-components

private struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let tint: Color

    var body: some View {
        GlassCard(padding: AppTheme.Spacing.sm) {
            VStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(tint)
                Text(value)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.primary.opacity(0.80))
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct QuickActionButton: View {
    let title: String
    let icon: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppTheme.Spacing.xs) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .glassEffect(in: Circle())
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(.primary.opacity(0.92))
            }
            .frame(maxWidth: .infinity)
        }
    }
}

#Preview {
    HomeView()
        .environment(AppState())
}
