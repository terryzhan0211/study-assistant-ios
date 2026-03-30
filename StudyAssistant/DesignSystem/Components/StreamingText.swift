import SwiftUI

/// Displays text that appears character-by-character, simulating a live streaming LLM response.
/// Used in the Chat view for typewriter-style token output.
struct StreamingText: View {
    let fullText: String
    var font: Font = .body
    var color: Color = .primary
    var delay: TimeInterval = 0.018

    @State private var displayedCharCount: Int = 0
    @State private var task: Task<Void, Never>?

    private var displayed: String {
        String(fullText.prefix(displayedCharCount))
    }

    var body: some View {
        Text(displayed)
            .font(font)
            .foregroundStyle(color)
            .onChange(of: fullText) { _, newValue in
                startStreaming(for: newValue)
            }
            .onAppear {
                startStreaming(for: fullText)
            }
            .onDisappear {
                task?.cancel()
            }
    }

    private func startStreaming(for text: String) {
        task?.cancel()
        displayedCharCount = 0
        guard !text.isEmpty else { return }

        task = Task {
            for index in text.indices {
                guard !Task.isCancelled else { return }
                try? await Task.sleep(for: .seconds(delay))
                if !Task.isCancelled {
                    displayedCharCount = text.distance(from: text.startIndex, to: index) + 1
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        MeshGradient.chatDark()
            .ignoresSafeArea()

        VStack(alignment: .leading, spacing: AppTheme.Spacing.md) {
            GlassCard {
                StreamingText(
                    fullText: "Here's a summary of today's lecture on photosynthesis. The key stages are light-dependent reactions and the Calvin cycle...",
                    font: .body,
                    delay: 0.025
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(AppTheme.Spacing.md)
    }
}
