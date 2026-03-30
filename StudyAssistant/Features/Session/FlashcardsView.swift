import SwiftUI

struct FlashcardsView: View {
    let transcript: String
    @Environment(\.dismiss) private var dismiss

    @Environment(AppState.self) private var appState
    @State private var deck: FlashcardDeck?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var currentIndex = 0
    @State private var isFlipped = false

    var body: some View {
        NavigationStack {
            ZStack {
                AdaptiveBackground(style: .session)

                Group {
                    if isLoading {
                        loadingView
                    } else if let error = errorMessage {
                        errorView(error)
                    } else if let deck {
                        deckView(deck)
                    }
                }
            }
            .navigationTitle(deck?.title ?? "Flashcards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await generate() }
        }
    }

    // MARK: - Deck UI

    private func deckView(_ deck: FlashcardDeck) -> some View {
        VStack(spacing: AppTheme.Spacing.lg) {
            // Progress
            Text("\(currentIndex + 1) of \(deck.cards.count)")
                .font(.caption)
                .foregroundStyle(.primary.opacity(0.65))

            // Card
            let card = deck.cards[currentIndex]
            FlipCard(front: card.front, back: card.back, isFlipped: $isFlipped)
                .frame(height: 260)
                .padding(.horizontal, AppTheme.Spacing.md)
                .onTapGesture { withAnimation(.spring(response: 0.45)) { isFlipped.toggle() } }

            Text(isFlipped ? "Tap to see question" : "Tap to reveal answer")
                .font(.caption)
                .foregroundStyle(.primary.opacity(0.50))

            // Navigation
            HStack(spacing: AppTheme.Spacing.xl) {
                Button {
                    navigate(by: -1, in: deck)
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title)
                        .foregroundStyle(.primary.opacity(currentIndex == 0 ? 0.25 : 0.80))
                }
                .disabled(currentIndex == 0)

                Button {
                    navigate(by: 1, in: deck)
                } label: {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.title)
                        .foregroundStyle(.primary.opacity(currentIndex == deck.cards.count - 1 ? 0.25 : 0.80))
                }
                .disabled(currentIndex == deck.cards.count - 1)
            }

            Spacer()
        }
        .padding(.top, AppTheme.Spacing.md)
    }

    private func navigate(by delta: Int, in deck: FlashcardDeck) {
        withAnimation(.spring(response: 0.3)) {
            isFlipped = false
            currentIndex = max(0, min(deck.cards.count - 1, currentIndex + delta))
        }
    }

    // MARK: - Loading / Error

    private var loadingView: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ProgressView().controlSize(.large)
            Text("Generating flashcards…")
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.72))
        }
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
                isLoading = true
                Task { await generate() }
            }
            .prominentButton(tint: .orange)
        }
        .padding(AppTheme.Spacing.xl)
    }

    // MARK: - Generation

    private func generate() async {
        isLoading = true
        defer { isLoading = false }
        do {
            deck = try await appState.ai.generateFlashcards(from: transcript)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Flip card component

private struct FlipCard: View {
    let front: String
    let back: String
    @Binding var isFlipped: Bool

    var body: some View {
        ZStack {
            cardFace(text: back,  icon: "checkmark",    tint: .blue)
                .rotation3DEffect(.degrees(isFlipped ? 0 : -90), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 1 : 0)

            cardFace(text: front, icon: "questionmark", tint: .orange)
                .rotation3DEffect(.degrees(isFlipped ? 90 : 0), axis: (x: 0, y: 1, z: 0))
                .opacity(isFlipped ? 0 : 1)
        }
    }

    private func cardFace(text: String, icon: String, tint: Color) -> some View {
        GlassCard(cornerRadius: AppTheme.Radius.xl, padding: AppTheme.Spacing.lg) {
            VStack(spacing: AppTheme.Spacing.sm) {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 36, height: 36)
                    .overlay(
                        Image(systemName: icon)
                            .font(.caption.bold())
                            .foregroundStyle(tint)
                    )

                Text(text)
                    .font(.body.bold())
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

#Preview {
    FlashcardsView(transcript: "The CAP theorem states that distributed systems can only guarantee two of three properties: Consistency, Availability, Partition tolerance.")
        .environment(AppState())
}
