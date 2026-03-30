import SwiftUI

struct QuizView: View {
    let transcript: String
    @Environment(\.dismiss) private var dismiss

    @Environment(AppState.self) private var appState
    @State private var quiz: QuizSet?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var currentIndex = 0
    @State private var selectedAnswer: String?
    @State private var score = 0
    @State private var showResults = false

    var body: some View {
        NavigationStack {
            ZStack {
                AdaptiveBackground(style: .study)

                Group {
                    if isLoading {
                        loadingView
                    } else if let error = errorMessage {
                        errorView(error)
                    } else if showResults, let quiz {
                        resultsView(quiz)
                    } else if let quiz {
                        questionView(quiz)
                    }
                }
            }
            .navigationTitle("Quiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .task { await generate() }
        }
    }

    // MARK: - Question

    private func questionView(_ quiz: QuizSet) -> some View {
        let q = quiz.questions[currentIndex]
        return ScrollView {
            VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                // Progress bar
                ProgressView(value: Double(currentIndex), total: Double(quiz.questions.count))
                    .tint(.purple)
                    .padding(.horizontal, AppTheme.Spacing.md)

                Text("Question \(currentIndex + 1) of \(quiz.questions.count)")
                    .font(.caption)
                    .foregroundStyle(.primary.opacity(0.65))
                    .padding(.horizontal, AppTheme.Spacing.md)

                // Question
                GlassCard {
                    Text(q.question)
                        .font(.body.bold())
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, AppTheme.Spacing.md)

                // Choices
                VStack(spacing: AppTheme.Spacing.sm) {
                    ForEach(q.choices, id: \.self) { choice in
                        AnswerButton(
                            text: choice,
                            state: answerState(for: choice, correct: q.correctAnswer)
                        ) {
                            guard selectedAnswer == nil else { return }
                            selectedAnswer = choice
                            if choice == q.correctAnswer { score += 1 }
                        }
                    }
                }
                .padding(.horizontal, AppTheme.Spacing.md)

                // Explanation (shown after answer)
                if selectedAnswer != nil {
                    GlassCard {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.xs) {
                            Label("Explanation", systemImage: "lightbulb.fill")
                                .font(.caption.bold())
                                .foregroundStyle(.yellow)
                            Text(q.explanation)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                        }
                    }
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .transition(.move(edge: .bottom).combined(with: .opacity))

                    Button(currentIndex < quiz.questions.count - 1 ? "Next Question →" : "See Results") {
                        advance(quiz)
                    }
                    .prominentButton(tint: .purple)
                    .padding(.horizontal, AppTheme.Spacing.md)
                    .transition(.opacity)
                }
            }
            .padding(.vertical, AppTheme.Spacing.md)
            .animation(.spring(response: 0.35), value: selectedAnswer)
        }
    }

    private func answerState(for choice: String, correct: String) -> AnswerButton.AnswerStatus {
        guard let selected = selectedAnswer else { return .idle }
        if choice == correct { return .correct }
        if choice == selected { return .wrong }
        return .idle
    }

    private func advance(_ quiz: QuizSet) {
        selectedAnswer = nil
        if currentIndex < quiz.questions.count - 1 {
            currentIndex += 1
        } else {
            showResults = true
        }
    }

    // MARK: - Results

    private func resultsView(_ quiz: QuizSet) -> some View {
        let pct = Int(Double(score) / Double(quiz.questions.count) * 100)
        return VStack(spacing: AppTheme.Spacing.lg) {
            Spacer()
            Image(systemName: pct >= 80 ? "star.fill" : pct >= 50 ? "hand.thumbsup.fill" : "book.fill")
                .font(.system(size: 64))
                .foregroundStyle(pct >= 80 ? Color.yellow : pct >= 50 ? Color.green : Color.orange)

            Text("\(score) / \(quiz.questions.count)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(pct >= 80 ? "Excellent work!" : pct >= 50 ? "Good effort!" : "Keep studying!")
                .font(.title3)
                .foregroundStyle(.primary.opacity(0.82))

            Text("\(pct)% correct")
                .font(.subheadline)
                .foregroundStyle(.primary.opacity(0.65))

            Spacer()

            Button("Done") { dismiss() }
                .prominentButton(tint: .purple)
                .padding(.horizontal, AppTheme.Spacing.xl)
        }
    }

    // MARK: - Loading / Error

    private var loadingView: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            ProgressView().controlSize(.large)
            Text("Generating quiz…")
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
            quiz = try await appState.ai.generateQuiz(from: transcript)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Answer button

private struct AnswerButton: View {
    enum AnswerStatus { case idle, correct, wrong }

    let text: String
    let state: AnswerStatus
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(labelColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if state == .correct {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                } else if state == .wrong {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                }
            }
            .padding(AppTheme.Spacing.sm)
            .background {
                RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                    .glassEffect(in: RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppTheme.Radius.md, style: .continuous)
                            .stroke(borderColor, lineWidth: state == .idle ? 0 : 2)
                    )
            }
        }
        .disabled(state != .idle)
    }

    private var labelColor: Color {
        switch state {
        case .idle:    .primary
        case .correct: .green
        case .wrong:   .red
        }
    }

    private var borderColor: Color {
        switch state {
        case .idle:    .clear
        case .correct: .green
        case .wrong:   .red
        }
    }
}

#Preview {
    QuizView(transcript: "The CAP theorem states that distributed systems can only guarantee two of three properties: Consistency, Availability, Partition tolerance.")
        .environment(AppState())
}
