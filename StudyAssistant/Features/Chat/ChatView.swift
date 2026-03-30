import SwiftUI
import SwiftData

// MARK: - Message model

struct ChatMessage: Identifiable {
    enum Role { case user, assistant }
    let id: UUID
    let role: Role
    var text: String          // var — updated in place during streaming
    var isStreaming: Bool

    static func user(_ text: String) -> ChatMessage {
        .init(id: .init(), role: .user, text: text, isStreaming: false)
    }
    static func assistant(_ text: String, streaming: Bool = false) -> ChatMessage {
        .init(id: .init(), role: .assistant, text: text, isStreaming: streaming)
    }
}

// MARK: - View

struct ChatView: View {
    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isThinking: Bool = false
    @State private var rag = RAGEngine()
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            ZStack {
                AdaptiveBackground(style: .chat)

                VStack(spacing: 0) {
                    messageList
                    inputBar
                }
            }
            .navigationTitle("AI Chat")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        messages = []
                        appState.ai.resetChat()
                        rag = RAGEngine()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .glassButton(tint: .primary)
                }
            }
        }
    }

    // MARK: Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: AppTheme.Spacing.sm) {
                    if messages.isEmpty {
                        placeholderSuggestions
                    } else {
                        ForEach(messages) { message in
                            MessageBubble(message: message).id(message.id)
                        }
                    }
                    if isThinking { thinkingIndicator }
                }
                .padding(AppTheme.Spacing.md)
                .padding(.bottom, AppTheme.Spacing.sm)
            }
            .onChange(of: messages.count) { _, _ in
                if let last = messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onChange(of: messages.last?.text) { _, _ in
                // Keep scrolled to bottom while streaming text grows
                if let last = messages.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: Placeholder

    private var placeholderSuggestions: some View {
        VStack(spacing: AppTheme.Spacing.sm) {
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.primary.opacity(0.70))
                .padding(.bottom, AppTheme.Spacing.sm)

            Text("Ask anything about your lectures")
                .font(.headline)
                .foregroundStyle(.primary)

            ForEach(suggestionChips, id: \.self) { suggestion in
                Button(suggestion) {
                    inputText = suggestion
                    sendMessage()
                }
                .glassButton(tint: .primary)
                .font(.subheadline)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, AppTheme.Spacing.xxl)
    }

    private let suggestionChips = [
        "Summarize today's session",
        "Generate flashcards",
        "What did I miss in lecture?"
    ]

    // MARK: Thinking indicator

    private var thinkingIndicator: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(.primary.opacity(0.75))
                    .frame(width: 8, height: 8)
                    .phaseAnimator([0.0, -6.0, 0.0]) { view, offset in
                        view.offset(y: offset)
                    } animation: { _ in
                        .easeInOut(duration: 0.4).delay(Double(i) * 0.15).repeatForever()
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, AppTheme.Spacing.md)
    }

    // MARK: Input bar

    private var inputBar: some View {
        HStack(spacing: AppTheme.Spacing.sm) {
            TextField("Ask about your notes...", text: $inputText, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, AppTheme.Spacing.sm)
                .padding(.vertical, AppTheme.Spacing.xs)

            Button {
                sendMessage()
            } label: {
                Image(systemName: inputText.isEmpty ? "mic.fill" : "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .symbolEffect(.bounce, value: inputText.isEmpty)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && isThinking)
        }
        .padding(AppTheme.Spacing.sm)
        .glassEffect(in: RoundedRectangle(cornerRadius: AppTheme.Radius.xl, style: .continuous))
        .padding(AppTheme.Spacing.md)
    }

    // MARK: Actions

    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        inputText = ""
        messages.append(.user(trimmed))
        isThinking = true   // dots show while retrieving context + waiting for first token

        Task {
            // Retrieve relevant notes and build a grounded prompt
            let prompt = await rag.groundedPrompt(for: trimmed, context: modelContext)

            var assistantIdx: Int? = nil
            do {
                for try await chunk in appState.ai.chat(message: prompt) {
                    if assistantIdx == nil {
                        // First token — swap thinking dots for streaming bubble
                        isThinking = false
                        messages.append(.assistant(chunk, streaming: true))
                        assistantIdx = messages.count - 1
                    } else {
                        messages[assistantIdx!].text = chunk
                    }
                }
            } catch {
                isThinking = false
                if let idx = assistantIdx {
                    messages[idx].text = error.localizedDescription
                } else {
                    messages.append(.assistant(error.localizedDescription))
                }
            }
            if let idx = assistantIdx {
                messages[idx].isStreaming = false
            } else {
                isThinking = false
            }
        }
    }
}

// MARK: - Message bubble

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 48) }

            Group {
                if message.isStreaming {
                    StreamingText(fullText: message.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(message.text)
                }
            }
            .padding(.horizontal, AppTheme.Spacing.md)
            .padding(.vertical, AppTheme.Spacing.sm)
            // User bubble: always white text on accentColor fill
            // Assistant bubble: primary (adaptive) on glass
            .foregroundStyle(message.role == .user ? Color.white : Color.primary)
            .background {
                if message.role == .user {
                    Capsule(style: .continuous)
                        .fill(Color.accentColor.gradient)
                } else {
                    RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous)
                        .glassEffect(in: RoundedRectangle(cornerRadius: AppTheme.Radius.lg, style: .continuous))
                }
            }

            if message.role == .assistant { Spacer(minLength: 48) }
        }
    }
}

#Preview {
    ChatView()
        .environment(AppState())
}
