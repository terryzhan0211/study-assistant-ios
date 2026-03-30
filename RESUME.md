# Resume Bullet Points — Study Assistant iOS

## One-liner

**AI Study Assistant** — Privacy-first iOS app with on-device LLM, real-time transcription, RAG, and cloud AI fallback (iOS 26, Swift 6, FoundationModels, AWS)

---

## Full Bullets

### AI & ML

- Built a hybrid AI routing layer using Apple FoundationModels (on-device 3B LLM) with automatic fallback to a self-hosted AWS LiteLLM gateway, achieving zero-latency private inference on supported devices
- Implemented a full RAG pipeline from scratch — chunked embeddings via `NLEmbedding`, cosine similarity search with Accelerate `vDSP`, and semantic context injection into grounded prompts — with keyword fallback for devices without NLP support
- Streamed structured AI output (flashcards, quiz questions) using both `@Generable` constrained decoding (on-device) and JSON-mode cloud completions, with a unified `AsyncThrowingStream` interface across both paths

### iOS / Swift

- Adopted Swift 6 strict concurrency (`SWIFT_STRICT_CONCURRENCY: complete`) across the entire codebase — all async boundaries modeled with `actor`, `@MainActor`, and `Sendable` conformances, zero data race warnings
- Engineered real-time lecture transcription using `AVAudioEngine` + `SFSpeechRecognizer` with a 60-second restart loop and cumulative transcript stitching, handling Apple's recognition session timeout transparently
- Built PDF ingestion with `PDFKit` + `Vision` OCR (`VNRecognizeTextRequest`) on a background thread, rendering pages synchronously on MainActor to satisfy Swift 6 Sendable requirements

### Infrastructure

- Deployed a self-hosted LiteLLM gateway on AWS EC2 behind NGINX with TLS termination, SSE streaming support, per-IP rate limiting, and a $50/month budget cap — routing traffic to OpenAI, Gemini, and Anthropic models
- Implemented OpenAI-compatible SSE streaming in Swift using `URLSession.bytes` and line-by-line `AsyncBytes` parsing, with cancellation propagated through `AsyncThrowingStream.onTermination`

### Design

- Delivered a full iOS 26 Liquid Glass design system — `glassEffect`, `MeshGradient` adaptive backgrounds, `@Observable` view models, and `phaseAnimator` streaming indicators — targeting the iOS 26 SDK before public release

---

## One-sentence Versions

- Built privacy-first iOS study app with on-device LLM inference, real-time speech transcription, PDF OCR, RAG retrieval, and AWS cloud AI fallback using Swift 6 and iOS 26 APIs
- Implemented end-to-end RAG pipeline (chunking → NLEmbedding → vDSP cosine search → grounded prompts) and dual-path AI streaming (Apple FoundationModels + LiteLLM gateway over SSE)
- Deployed self-hosted LiteLLM on AWS EC2 with NGINX/TLS and integrated it into an iOS app as a cloud fallback via OpenAI-compatible SSE streaming
