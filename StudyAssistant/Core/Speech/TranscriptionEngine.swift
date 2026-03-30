import AVFoundation
import Speech
import SwiftUI

// MARK: - Engine status

enum TranscriptionStatus: Equatable {
    case idle
    case requestingPermission
    case recording
    case paused
    case error(String)

    var isActive: Bool { self == .recording || self == .paused }
}

// MARK: - Engine

/// Manages the full audio capture + live transcription pipeline.
///
/// Primary path: AVAudioEngine + SFSpeechRecognizer (iOS 13+, works on iOS 26).
/// Handles the ~60-second SFSpeechRecognizer limit by restarting the recognition
/// task automatically and accumulating the transcript across restarts.
///
/// TODO: Replace SFSpeechRecognizer with iOS 26 `SpeechTranscriber` for lower
///       latency and on-device word-level timestamps once the exact API is stable.
@MainActor
@Observable
final class TranscriptionEngine {

    // MARK: Published state

    var status: TranscriptionStatus = .idle
    var liveTranscript: String = ""
    var audioLevel: Float = 0          // 0.0 – 1.0, normalised RMS
    var elapsed: TimeInterval = 0

    // MARK: Private

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: .autoupdatingCurrent)
    private var elapsedTimer: Timer?
    private var startDate: Date?
    private var isStopping = false
    /// Accumulates text across SFSpeechRecognizer restarts (it has a ~60s limit).
    private var cumulativeTranscript = ""

    // MARK: - Permissions

    func requestPermissions() async -> Bool {
        status = .requestingPermission

        let speechGranted = await withCheckedContinuation { cont in
            SFSpeechRecognizer.requestAuthorization { cont.resume(returning: $0 == .authorized) }
        }
        guard speechGranted else { status = .error("Speech recognition denied"); return false }

        let micGranted = await AVAudioApplication.requestRecordPermission()
        guard micGranted else { status = .error("Microphone access denied"); return false }

        status = .idle
        return true
    }

    // MARK: - Recording lifecycle

    func startRecording() async throws {
        guard speechRecognizer?.isAvailable == true else {
            status = .error("Speech recognition unavailable on this device")
            return
        }
        isStopping = false
        cumulativeTranscript = ""
        liveTranscript = ""
        elapsed = 0

        // Audio session
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        // Install audio tap — feeds buffers to whichever recognition request is active
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            let level = buffer.rmsLevel
            Task { @MainActor [weak self] in
                self?.audioLevel = min(level * 10, 1.0)
            }
        }

        audioEngine.prepare()
        try audioEngine.start()

        // Start the first recognition task (auto-restarts on timeout)
        startRecognitionTask()

        // Elapsed timer
        startDate = Date()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let start = self.startDate else { return }
                self.elapsed = Date().timeIntervalSince(start)
            }
        }

        status = .recording
    }

    /// Starts (or restarts) a recognition task against the current audio tap.
    /// Called once at the start of recording and again each time the recogniser
    /// hits its ~60-second limit.
    private func startRecognitionTask() {
        recognitionTask?.cancel()

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        recognitionRequest = request

        recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                if let result {
                    let sessionText = result.bestTranscription.formattedString
                    self.liveTranscript = self.cumulativeTranscript.isEmpty
                        ? sessionText
                        : self.cumulativeTranscript + " " + sessionText
                }

                let shouldRestart = !self.isStopping && self.status == .recording

                if let error {
                    let code = (error as NSError).code
                    // 1110 = no speech detected; 216 = task cancelled — normal endings
                    let isNormalEnd = (code == 1110 || code == 216)

                    if isNormalEnd && shouldRestart {
                        // Accumulate and start a fresh task seamlessly
                        self.cumulativeTranscript = self.liveTranscript
                        self.startRecognitionTask()
                    } else if !isNormalEnd && shouldRestart {
                        self.status = .error(error.localizedDescription)
                    }
                } else if let result, result.isFinal, shouldRestart {
                    // Reached the recogniser's time limit — restart automatically
                    self.cumulativeTranscript = self.liveTranscript
                    self.startRecognitionTask()
                }
            }
        }
    }

    /// Stops recording and returns the final transcript.
    @discardableResult
    func stopRecording() -> String {
        isStopping = true

        elapsedTimer?.invalidate()
        elapsedTimer = nil

        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil

        try? AVAudioSession.sharedInstance().setActive(
            false, options: .notifyOthersOnDeactivation
        )

        let final = liveTranscript
        status = .idle
        audioLevel = 0
        return final
    }

    func pauseRecording() {
        guard status == .recording else { return }
        audioEngine.pause()
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        status = .paused
    }

    func resumeRecording() throws {
        guard status == .paused else { return }
        try audioEngine.start()
        // Restore elapsed timer
        let elapsed = self.elapsed
        startDate = Date().addingTimeInterval(-elapsed)
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let start = self.startDate else { return }
                self.elapsed = Date().timeIntervalSince(start)
            }
        }
        status = .recording
    }

    func reset() {
        liveTranscript = ""
        cumulativeTranscript = ""
        elapsed = 0
        audioLevel = 0
        startDate = nil
    }
}

// MARK: - AVAudioPCMBuffer helpers

extension AVAudioPCMBuffer {
    /// Root-mean-square audio level for the first channel (0.0 – 1.0 range).
    var rmsLevel: Float {
        guard let data = floatChannelData, frameLength > 0 else { return 0 }
        let frames = Int(frameLength)
        let channel = data[0]
        var sum: Float = 0
        for i in 0..<frames { sum += channel[i] * channel[i] }
        return sqrt(sum / Float(frames))
    }
}
