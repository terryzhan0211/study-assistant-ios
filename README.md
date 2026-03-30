# Study Assistant iOS

A privacy-first iOS study app that transcribes lectures, imports PDFs, and answers questions about your notes using on-device AI — with a cloud fallback when needed.

## Features

- **Live Transcription** — Records lectures in real time using `AVAudioEngine` + `SFSpeechRecognizer` with automatic session restart to bypass Apple's 60-second recognition limit
- **PDF Import** — Imports and indexes PDFs via `PDFKit` + `Vision` OCR for full-text search and AI grounding
- **On-Device AI** — Summarizes sessions, generates flashcards, creates quizzes, and answers questions using Apple FoundationModels (iOS 26, no data leaves the device)
- **RAG Pipeline** — Retrieves relevant notes before answering using `NLEmbedding` sentence vectors and cosine similarity search via Accelerate `vDSP`
- **Cloud Fallback** — When on-device AI is unavailable, routes requests to a self-hosted LiteLLM gateway supporting OpenAI, Gemini, and Anthropic models
- **Streaming UI** — All AI responses stream token-by-token with Liquid Glass bubble UI

## Requirements

- Xcode 26.3+
- iOS 26.0+ (on-device AI requires a device with Apple Intelligence)
- [xcodegen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

## Getting Started

```bash
git clone https://github.com/terryzhan0211/study-assistant-ios.git
cd study-assistant-ios
xcodegen generate
open StudyAssistant.xcodeproj
```

Run on simulator or device. On simulator, configure a cloud gateway in **Settings** to enable AI features.

## Architecture

```
StudyAssistant/
├── App/                        # AppState, RootView, entry point
├── Core/
│   ├── Intelligence/           # AIService, CloudGatewayClient, GatewayConfig
│   ├── RAG/                    # RAGEngine, EmbeddingService, TextChunker
│   ├── Speech/                 # TranscriptionEngine, WhisperKitProcessor
│   └── Documents/              # DocumentImporter (PDFKit + Vision OCR)
├── Features/
│   ├── Chat/                   # AI chat with RAG-grounded prompts
│   ├── Session/                # Recording, transcript, summary, flashcards, quiz
│   ├── Documents/              # PDF viewer + text extraction
│   ├── Home/                   # Dashboard
│   └── Settings/               # Gateway config, AI status
├── Persistence/
│   └── Models/                 # SwiftData: RecordingSession, StudyDocument, TextChunk
└── DesignSystem/               # Liquid Glass components, AppTheme
```

### AI Routing

```
Request
  └─ Apple Intelligence available? ──Yes──▶ FoundationModels (on-device, private)
           │
           No
           └─ Gateway configured? ──Yes──▶ LiteLLM Gateway (cloud)
                      │
                      No
                      └─▶ Friendly error
```

## Cloud Gateway (Optional)

The `server/` directory contains a ready-to-deploy stack:

| File | Purpose |
|---|---|
| `docker-compose.yml` | LiteLLM + NGINX containers |
| `litellm_config.yaml` | Model routing (GPT-4o, Gemini, Claude) |
| `nginx.conf` | HTTPS reverse proxy with SSE support |
| `setup.sh` | EC2 Ubuntu bootstrap |

```bash
# On EC2 Ubuntu 24.04
sudo bash server/setup.sh
cp server/.env.example server/.env   # add API keys
cd server && docker compose up -d
```

Then in **Settings**, enter your gateway URL and API key.

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 6 (strict concurrency) |
| UI | SwiftUI + iOS 26 Liquid Glass |
| Persistence | SwiftData |
| On-device AI | Apple FoundationModels (`LanguageModelSession`, `@Generable`) |
| Embeddings | `NLEmbedding` + Accelerate `vDSP` |
| Transcription | `AVAudioEngine` + `SFSpeechRecognizer` |
| PDF | `PDFKit` + `Vision` (`VNRecognizeTextRequest`) |
| Cloud AI | LiteLLM (OpenAI-compatible SSE) |
| Server | Docker, NGINX, AWS EC2 |
