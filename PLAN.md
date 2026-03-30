# AI Study Assistant — iOS App Development Plan (v2)

## Overview

A high-performance, privacy-first study assistant built **local-first**. The architecture
shifts AI inference onto the device using the iOS 26 Foundation Models framework — zero
token cost, instant response, 100% private — while an AWS backend handles heavy research
queries and cross-device sync.

---

## Tech Stack — The "Hybrid" Architecture

| Layer | Technology | Why? |
|---|---|---|
| UI | SwiftUI + Liquid Glass | Native iOS 26 design system with translucent effects |
| AI (Local) | Foundation Models Framework | On-device 3B LLM; $0 token cost; 100% private |
| AI (Cloud) | FastAPI + LiteLLM (AWS) | Gateway to Gemini 1.5 Pro / GPT-4o for research |
| Speech | SpeechTranscriber API | iOS 26 native high-speed streaming transcription |
| RAG | sqlite-vec + SwiftData | On-device vector search for offline PDF intelligence |
| Backend | Docker on AWS EC2 | Centralized storage, sync, and API key management |

---

## Architecture

```
graph TD
    A[iOS App: Liquid UI] --> B{Intelligence Router}
    B -->|Simple/Private| C[Apple Foundation Models]
    B -->|Complex/Research| D[AWS Backend Gateway]
    D --> E[Gemini / GPT-4o]
    A --> F[Local RAG: sqlite-vec]
    A --> G[SpeechTranscriber]
    F -.-> B
```

```
┌────────────────────────────────────────────────────┐
│                 iOS App (Liquid Glass UI)           │
│                                                    │
│  SpeechTranscriber ──► Session View                │
│                                                    │
│  PDFKit + OCR ──► VectorStore (sqlite-vec) ──┐     │
│                                              │     │
│                         ┌────────────────────▼──┐  │
│                         │  Intelligence Router  │  │
│                         └──────────┬────────────┘  │
│                    ┌───────────────┴──────────┐     │
│              Local (private)          Cloud (pro)   │
│         Foundation Models         AWS LiteLLM GW    │
└────────────────────────────────────────────────────┘
                                        │
                              ┌─────────▼──────────┐
                              │  FastAPI / LiteLLM  │
                              │  Gemini / GPT-4o    │
                              │  AWS EC2 + NGINX    │
                              └────────────────────┘
```

---

## Phases

### Phase 1 — Scaffold & Liquid UI
**Goal:** Establish the iOS 26 visual identity and project architecture.

- [ ] Xcode 26 project with Swift 6 strict concurrency enabled
- [ ] Liquid Glass design system — `.glassEffect()` surfaces, `MeshGradient` backgrounds
- [ ] MVVM-C architecture with `IntelligenceCoordinator` for model routing
- [ ] Tab shell: Home, Sessions, Documents, Chat
- [ ] Reusable `GlassCard`, `GlassButton`, `StreamingText` components

**Deliverable:** Navigable shell with the "2026 vibe."

---

### Phase 2 — High-Speed Transcription
**Goal:** Native, real-time lecture capture.

- [ ] `SpeechTranscriber` API — zero-latency live captions with word-level timestamps
- [ ] `SoundAnalysis` framework — speaker diarization (Prof vs. Student)
- [ ] Background `WhisperKit` pass — high-accuracy post-session correction
- [ ] Live transcript view with word highlighting and speaker labels
- [ ] Export to `.txt` / `.md`

**Deliverable:** Real-time transcription screen with live word highlighting.

---

### Phase 3 — Document Intelligence (PDF)
**Goal:** Native ingestion and local vectorization.

- [ ] PDFKit viewer with annotation support
- [ ] `Vision` framework OCR for scanned/handwritten handouts
- [ ] `SwiftData` persistence — document metadata, study tags, session links
- [ ] Local RAG pipeline:
  - Text chunking (paragraph / page boundary)
  - `NaturalLanguage` / `NLContextualEmbedding` for vector generation
  - `sqlite-vec` for fast cosine similarity search

**Deliverable:** Full document library with automated local indexing.

---

### Phase 4 — On-Device Intelligence (The Brain)
**Goal:** Implement the "Free & Private" AI core.

- [ ] Capability check: `SystemLanguageModel.default.availability`
- [ ] `LanguageModelSession` — local 3B model for summaries, Q&A, flashcards
- [ ] Guided generation: `@Generable` structs for guaranteed valid study schemas
  ```swift
  @Generable struct FlashcardDeck {
      var cards: [Flashcard]
  }
  @Generable struct Flashcard {
      var question: String
      var answer: String
  }
  ```
- [ ] Session summary generation from transcript + retrieved slide chunks

**Deliverable:** Instant, offline AI summaries at $0 token cost.

---

### Phase 5 — Context-Aware Chat & Tools
**Goal:** Unified interface for local and cloud intelligence.

- [ ] **Intelligence Router** — `IntelligenceCoordinator` decision logic:
  - Local model: summarize, flashcards, notes Q&A (fast + private)
  - Cloud gateway: web knowledge, complex research, multi-doc reasoning
- [ ] **Streaming UI** — `streamResponse` with typewriter-style `StreamingText`
- [ ] **Tool Calling** — implement `Tool` protocol:
  - `SearchNotesTool` — RAG query over local vector store
  - `AddToCalendarTool` — EventKit integration
  - `SummarizeDocumentTool` — local Foundation Model call
- [ ] Conversation history scoped per session

**Deliverable:** Chatbot grounded in session context with cloud-fallback for research.

---

### Phase 6 — Backend LLM Gateway (AWS)
**Goal:** Secure, scalable research engine.

- [ ] **FastAPI + LiteLLM** — centralized gateway routing to Gemini 1.5 Pro / GPT-4o
- [ ] **AWS Deployment** — Docker container, NGINX reverse proxy, EC2
- [ ] **Security** — API keys in AWS Secrets Manager; app never handles raw keys
- [ ] **Caching** — Redis layer for repeated research queries
- [ ] **Sync** — S3 document storage + session metadata sync endpoint

**Deliverable:** Production API for "Pro" research features and cross-device sync.

---

### Phase 7 — Campus & System Integration
**Goal:** Deep OS-level integration for student workflows.

- [ ] **Writing Tools API** — system-wide extension for summarization in any app
- [ ] **EventKit** — AI-triggered exam reminders, smart study session scheduling
- [ ] Auto-label sessions from campus calendar data (optional OAuth / LMS API)

**Deliverable:** App-wide tools that interact with the student's ecosystem.

---

## Directory Structure

```
iosApp/
├── App/
│   ├── AppEntry.swift
│   └── AppState.swift
├── Core/
│   ├── Intelligence/         # IntelligenceCoordinator, FoundationModels wrapper, Cloud router
│   ├── VectorStore/          # sqlite-vec + NLContextualEmbedding
│   ├── Network/              # FastAPI/LiteLLM client, SSE streaming
│   └── Persistence/          # SwiftData models and migrations
├── Features/
│   ├── Home/                 # MeshGradient dashboard
│   ├── Session/              # SpeechTranscriber + recording UI
│   ├── Documents/            # PDFKit viewer + chunking engine
│   ├── Chat/                 # Streaming UI + Tool Calling
│   └── Settings/
├── Models/
│   └── Generable/            # @Generable structs (FlashcardDeck, Summary, etc.)
└── DesignSystem/
    ├── Components/           # GlassCard, GlassButton, StreamingText
    └── Theme/                # MeshGradient presets, typography
```

---

## Key Risks & Mitigations

| Risk | Mitigation |
|---|---|
| Hardware limitations (Foundation Models needs iPhone 15 Pro+) | `SystemLanguageModel.default.availability` check; auto-fallback to Cloud Gateway |
| Token cost creep | 90% of tasks routed to local model; cloud gated behind "Pro" tier |
| Model hallucination | `@Generable` + guided generation enforces strict JSON schemas |
| 4k context window on 3B model | Sliding window RAG — feed only top 3–4 relevant chunks |
| iOS 26 beta instability | Keep a `#if canImport` guard around all iOS 26 APIs with graceful degradation |

---

## Milestones (Vibe Coding Pace)

| Target | Milestone |
|---|---|
| Day 1 | Project scaffold + Liquid Glass UI + backend gateway live |
| Day 2 | Native transcription (`SpeechTranscriber`) + local AI (`LanguageModelSession`) |
| Day 3 | PDF ingestion + local vector search (RAG pipeline end-to-end) |
| Day 4 | Tool calling + Intelligence Router (local ↔ cloud fallback logic) |
| Day 5 | Testing, polish, and demo recording |
