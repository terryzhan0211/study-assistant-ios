import Foundation

/// Post-session high-accuracy correction pass using WhisperKit (on-device Whisper model).
///
/// Phase 2: skeleton only.
/// To activate:
///   1. The WhisperKit package is already declared in project.yml.
///   2. Add `import WhisperKit` and implement `correct(transcript:audioURL:)` below.
///   3. Model download (~1.5 GB for whisper-large-v3) happens on first use.
@MainActor
@Observable
final class WhisperKitProcessor {

    enum ProcessingState {
        case idle
        case downloading(progress: Double)
        case transcribing
        case done(String)
        case error(String)
    }

    var state: ProcessingState = .idle

    /// Run WhisperKit correction on a completed session's audio file.
    /// Returns the corrected transcript, or `nil` if WhisperKit is not yet integrated.
    func correct(transcript: String, audioURL: URL?) async -> String? {
        // TODO Phase 2 — WhisperKit integration:
        //
        // import WhisperKit
        //
        // let whisper = try await WhisperKit(model: "openai_whisper-base.en")
        // guard let url = audioURL else { return nil }
        // let results = try await whisper.transcribe(audioPath: url.path)
        // return results.map(\.text).joined(separator: " ")
        //
        // For now, fall through to the live SFSpeechRecognizer transcript.
        return nil
    }
}
