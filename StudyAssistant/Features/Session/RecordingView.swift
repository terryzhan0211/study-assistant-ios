import SwiftUI
import SwiftData

struct RecordingView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var engine = TranscriptionEngine()
    @State private var sessionTitle = "New Session"
    @State private var isEditingTitle = false
    @State private var savedSession: RecordingSession?
    @State private var showDetail = false

    var body: some View {
        NavigationStack {
            ZStack {
                AdaptiveBackground(style: .session)

                VStack(spacing: 0) {
                    titleSection
                        .padding(.top, AppTheme.Spacing.lg)

                    Spacer()

                    waveformSection

                    Spacer()

                    liveTranscriptSection

                    Spacer()

                    controlsSection
                        .padding(.bottom, AppTheme.Spacing.xl)
                }
                .padding(.horizontal, AppTheme.Spacing.md)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .navigationDestination(isPresented: $showDetail) {
                if let session = savedSession {
                    SessionDetailView(session: session)
                }
            }
        }
        .interactiveDismissDisabled(engine.status.isActive)
    }

    // MARK: - Title

    private var titleSection: some View {
        VStack(spacing: AppTheme.Spacing.xs) {
            if isEditingTitle {
                TextField("Session title", text: $sessionTitle)
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .foregroundStyle(.primary)
                    .onSubmit { isEditingTitle = false }
            } else {
                Button {
                    isEditingTitle = true
                } label: {
                    HStack(spacing: 6) {
                        Text(sessionTitle)
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundStyle(.primary.opacity(0.55))
                    }
                }
            }

            if engine.status == .recording || engine.status == .paused {
                HStack(spacing: AppTheme.Spacing.xs) {
                    Circle()
                        .fill(engine.status == .recording ? Color.red : Color.orange)
                        .frame(width: 8, height: 8)
                        .opacity(engine.status == .recording ? 1 : 0.6)
                        .phaseAnimator([1.0, 0.4, 1.0]) { view, opacity in
                            view.opacity(engine.status == .recording ? opacity : 0.6)
                        } animation: { _ in
                            .easeInOut(duration: 0.8).repeatForever()
                        }

                    Text(engine.status == .recording ? "Recording" : "Paused")
                        .font(.caption.bold())
                        .foregroundStyle(.primary.opacity(0.80))

                    Text("·")
                        .foregroundStyle(.primary.opacity(0.45))

                    Text(formattedElapsed)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.primary.opacity(0.80))
                }
            }
        }
    }

    // MARK: - Waveform

    private var waveformSection: some View {
        Group {
            if engine.status.isActive {
                WaveformView(level: engine.audioLevel, color: .orange, maxHeight: 72)
                    .frame(height: 80)
            } else {
                IdleWaveformView()
                    .frame(height: 80)
            }
        }
        .padding(.vertical, AppTheme.Spacing.lg)
    }

    // MARK: - Live transcript

    private var liveTranscriptSection: some View {
        GlassCard(cornerRadius: AppTheme.Radius.lg) {
            ScrollViewReader { proxy in
                ScrollView {
                    Text(
                        engine.liveTranscript.isEmpty
                            ? (engine.status == .idle ? "Tap record to begin…" : "Listening…")
                            : engine.liveTranscript
                    )
                    .font(.body)
                    .foregroundStyle(Color.primary.opacity(engine.liveTranscript.isEmpty ? 0.45 : 1.0))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id("bottom")
                }
                .frame(height: 180)
                .onChange(of: engine.liveTranscript) { _, _ in
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
        }
    }

    // MARK: - Controls

    private var controlsSection: some View {
        HStack(spacing: AppTheme.Spacing.xl) {
            // Pause / Resume
            if engine.status.isActive {
                Button {
                    if engine.status == .recording {
                        engine.pauseRecording()
                    } else {
                        do {
                            try engine.resumeRecording()
                        } catch {
                            engine.status = .error(error.localizedDescription)
                        }
                    }
                } label: {
                    Image(systemName: engine.status == .recording ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundStyle(.primary.opacity(0.80))
                        .frame(width: 52, height: 52)
                        .glassEffect(in: Circle())
                }
            }

            // Record / Stop button
            Button {
                handleRecordStop()
            } label: {
                ZStack {
                    Circle()
                        .fill(engine.status.isActive ? Color.red : Color.orange)
                        .frame(width: 72, height: 72)

                    if engine.status.isActive {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(.white)
                            .frame(width: 26, height: 26)
                    } else {
                        Circle()
                            .fill(.white)
                            .frame(width: 28, height: 28)
                    }
                }
                .shadow(color: (engine.status.isActive ? Color.red : Color.orange).opacity(0.45),
                        radius: 16, y: 6)
            }
            .scaleEffect(engine.status.isActive ? 1.05 : 1.0)
            .animation(.spring(response: 0.3), value: engine.status.isActive)

            // Placeholder for symmetry / future action
            if engine.status.isActive {
                Color.clear.frame(width: 52, height: 52)
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close") {
                if engine.status.isActive { engine.stopRecording() }
                dismiss()
            }
        }
    }

    // MARK: - Actions

    private func handleRecordStop() {
        switch engine.status {
        case .idle:
            Task {
                let granted = await engine.requestPermissions()
                guard granted else { return }
                do {
                    try await engine.startRecording()
                } catch {
                    engine.status = .error(error.localizedDescription)
                }
            }
        case .recording, .paused:
            let transcript = engine.stopRecording()
            let session = RecordingSession(title: sessionTitle)
            session.transcript = transcript
            session.durationSeconds = Int(engine.elapsed)
            modelContext.insert(session)
            savedSession = session
            engine.reset()
            showDetail = true
        default:
            break
        }
    }

    // MARK: - Helpers

    private var formattedElapsed: String {
        let total = Int(engine.elapsed)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}

#Preview {
    RecordingView()
        .modelContainer(for: RecordingSession.self, inMemory: true)
        .environment(AppState())
}
