import FoundationModels

// MARK: - Structured generation types
// All types are @Generable so the Foundation Models framework can produce them
// via constrained decoding (no post-processing / parsing required).

@Generable
struct Flashcard {
    /// The question / term shown on the front of the card.
    var front: String
    /// The answer / definition shown after the card is flipped.
    var back: String
}

@Generable
struct FlashcardDeck {
    /// Short descriptive title for the deck.
    var title: String
    /// 5 – 10 flashcards covering the key concepts.
    var cards: [Flashcard]
}

@Generable
struct QuizQuestion {
    /// The question text.
    var question: String
    /// Exactly 4 answer choices.
    var choices: [String]
    /// The text of the correct choice (must match one entry in `choices` exactly).
    var correctAnswer: String
    /// One-sentence explanation of why the answer is correct.
    var explanation: String
}

@Generable
struct QuizSet {
    /// 4 – 6 multiple-choice questions covering the lecture content.
    var questions: [QuizQuestion]
}
