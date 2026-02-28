# Reef iOS

## File Map — `Services/`

| Service | Purpose |
|---------|---------|
| `AIService.swift` | REST + SSE client for Reef-Server: stroke logging, embeddings, voice transcription, TTS streaming |
| `AuthenticationManager.swift` | Apple Sign-In, Keychain persistence, profile sync with server |
| `RAGService.swift` | RAG orchestrator: document chunking → embedding → vector search → context retrieval |
| `EmbeddingService.swift` | Server-side MiniLM-L6-v2 embeddings (384-dim), batch processing, cosine similarity via Accelerate |
| `VectorStore.swift` | SQLite-based vector DB (AppSupport/Reef/vectors.sqlite), semantic search |
| `VectorMigrationService.swift` | Re-indexes documents when embedding version changes |
| `TextChunker.swift` | Semantic chunking: 1000-char targets, 200-1500 range, respects headers/page breaks |
| `DocumentTextExtractor.swift` | Hybrid text extraction orchestrator: PDFKit embedded + Vision OCR |
| `PDFTextExtractor.swift` | Extracts embedded text from PDFs using PDFKit |
| `OCRTextExtractor.swift` | Vision framework OCR for images and scanned PDFs |
| `FileStorageService.swift` | Document storage in Documents/Documents/, security-scoped access |
| `VoiceRecordingService.swift` | Push-to-talk WAV recording (16kHz, mono, 16-bit PCM) |
| `QuizGenerationService.swift` | Generates quizzes via server API, receives base64 PDF questions |
| `QuestionExtractionService.swift` | Extracts assignment questions from documents for question-by-question mode |
| `PDFExportService.swift` | Exports drawn canvas pages as PDF |
| `PDFThumbnailGenerator.swift` | Generates thumbnails for document previews |
| `DrawingStorageService.swift` | Persists PencilKit drawing data |
| `PreferencesManager.swift` | Preferences: reasoning model, feedback detail, recognition language, difficulty |
| `UserPreferencesManager.swift` | Preferences: pinned courses, tutor selection, study settings |
| `TutorSelectionManager.swift` | Selected AI tutor persona and preset modes |
| `NavigationStateManager.swift` | Persists nav state across restarts via @AppStorage |
| `KeychainService.swift` | Secure storage (service: com.reef.auth): user ID, name, email |
| `ProfileService.swift` | Syncs user profile with server (display_name, email) |
| `StudyStatsService.swift` | Analytics: session tracking, study time, quiz/exam performance |

## File Map — `Views/`

```
Views/
├── HomeView.swift                     — Main NavigationSplitView: sidebar + detail
├── PreAuthView.swift                  — Apple Sign-In, gradient background
├── Canvas/
│   ├── CanvasView.swift               — Main canvas controller: drawing, tools, voice
│   ├── ReefCanvasView.swift           — PKCanvasView subclass: custom eraser cursor
│   ├── DrawingOverlayView.swift       — PencilKit drawing surface
│   ├── CanvasToolbar.swift            — Tool selection: pen, highlighter, eraser, text
│   ├── ContextualToolbar.swift        — Contextual menu for selected objects
│   ├── TextBoxContainerView.swift     — Editable text boxes on canvas
│   ├── TextBoxData.swift              — TextBox model: position, text, color, size
│   ├── AssignmentView.swift           — Question navigator for assignments/quizzes
│   └── RecognitionFeedbackView.swift  — Handwriting/stroke recognition results
├── Home/
│   ├── DashboardView.swift            — Recent notes, pinned items, quick actions
│   ├── AnalyticsView.swift            — Study stats overview
│   ├── AnalyticsBarChartView.swift    — Bar charts for trends
│   ├── AnalyticsDonutView.swift       — Pie/donut charts
│   ├── StatsRowView.swift             — Single stat row component
│   ├── PinnedItemsView.swift          — Pinned courses/notes
│   ├── RecentItemsView.swift          — Recently opened docs
│   └── WeeklyActivityView.swift       — Study activity heatmap/timeline
├── Notes/
│   ├── NotesView.swift                — List of notes in course
│   └── DocumentPicker.swift           — File picker for PDF/image import
├── Course/
│   └── CourseDetailView.swift         — Course overview: notes/quizzes/exams tabs
├── Quizzes/
│   └── QuizzesView.swift              — List of quizzes, generation UI
├── Exams/
│   └── ExamsView.swift                — List of exams, attempt history
├── Tutors/
│   ├── TutorsView.swift               — Tutor catalog grid
│   └── TutorCardView.swift            — Single tutor card with lore/fun facts
├── Settings/
│   ├── SettingsView.swift             — Main settings nav
│   ├── AccountSettingsView.swift      — User profile, sign-out
│   ├── AISettingsView.swift           — Reasoning model, feedback level, language
│   ├── StudySettingsView.swift        — Handwriting model, difficulty, tutor mode
│   ├── PrivacySettingsView.swift      — Privacy & data policy
│   └── AboutView.swift               — App version, credits
└── Components/
    ├── FloatingAddButton.swift        — FAB for creating documents
    ├── UploadOptionsSheet.swift       — Assignment mode toggle on upload
    ├── DocumentGridItem.swift         — Grid item for document thumbnails
    ├── FilterBar.swift                — Filter/search toolbar
    └── SkeletonShimmer.swift          — Loading placeholder animation
```

## File Map — `Models/`

| Model | Purpose |
|-------|---------|
| `Note.swift` | SwiftData: document with extraction status, assignment mode, extracted questions, isVectorIndexed |
| `Quiz.swift` | SwiftData: generated quiz with topic, difficulty, questions (PDF filenames), source notes |
| `ExamAttempt.swift` | SwiftData: exam session with questions, score, weak areas, passing score |
| `Tutor.swift` | Non-Model: 16 AI tutor personas (Finn, Coral, Shelly, Pearl, etc.) with emoji, species, personality, voice, lore |

## Navigation Structure

```
NavigationSplitView (3-column on iPad)
├── Sidebar
│   ├── Home, My Reef, Analytics, Tutors, Settings
│   └── Course list (pinned first, then alphabetical)
├── Detail
│   ├── CourseDetailView (notes/quizzes/exams tabs)
│   ├── DashboardView / AnalyticsView / TutorsView / SettingsView
│   └── Toolbar: title, pin toggle, add button, theme toggle
└── Canvas Overlay (ZStack, slides in from right)
    ├── Full-screen drawing + PDF markup
    ├── Assignment mode: question navigator (Q1/10)
    └── Toolbar: tools, voice, undo/redo, export, rulers, text
```

Navigation state persisted via `NavigationStateManager` (@AppStorage): selectedSidebarItem, selectedCourseID, selectedCourseSubPage, selectedNoteID, isViewingCanvas.

## Data Flows

### Stroke Flow (draw → server → reasoning feedback)

```
PencilKit draw → CanvasView collects [[[Double]]] points
  ↓ fire-and-forget POST /api/strokes (session_id, page, strokes, event_type)
  ↓ no immediate response — server clusters + reasons async
  ↓ reasoning arrives via SSE event: {"action":"speak","message":"...","tts_id":"..."}
  ↓ iOS fetches GET /api/tts/stream/{tts_id} → chunked PCM audio playback
```

### Voice Flow

```
VoiceRecordingService captures WAV (16kHz, mono, 16-bit PCM)
  ↓ POST /api/voice/question (multipart: audio + session_id + page)
  ↓ server transcribes (Groq Whisper) → returns {"transcription": "..."}
  ↓ async reasoning → SSE event with tts_id → TTS audio stream
```

### RAG Flow (document indexing → retrieval)

```
Document uploaded → DocumentTextExtractor (PDFKit + Vision OCR)
  ↓ TextChunker.chunk() (1000-char targets, respects headers)
  ↓ EmbeddingService.embedBatch() → server MiniLM (384-dim)
  ↓ VectorStore.index() → SQLite (AppSupport/Reef/vectors.sqlite)

On query: embed query → VectorStore.search(topK=5) → similarity > 0.15 → format context
```

### Quiz Generation

```
QuizzesView → QuizGenerationService.generate(topic, difficulty, numQuestions)
  ↓ RAGService.getContext(topic, courseId) → top chunks
  ↓ POST /ai/generate-quiz with rag_context
  ↓ server returns [QuizQuestionResponse] (base64 PDFs)
  ↓ write PDFs locally, create Quiz SwiftData model
```

## Fonts & Colors

### Custom Fonts
- **DynaPuff** (playful): Regular, Medium, SemiBold, Bold — headlines, app title
- **Quicksand** (friendly): Light, Regular, Medium, SemiBold, Bold — all UI text

### Color Palette (ReefColors.swift)

**Light mode**: softCoral (#F9C1B6, CTA), deepCoral (#D4877A, emphasis), deepTeal (#5B9E9B, links/icons), seafoam (#C3DFDE, secondary), charcoal (#2B2B2B, text), blushWhite (#F9F5F6, background)

**Dark mode**: warmDark (#1A1418, background), warmDarkCard (#251E22, cards), warmWhite (#F5F0EE, text), brightTealDark (#7CB5AC, links)

**Gradients**: `reefWarm` (deepCoral → softCoral → seafoam), `reefCoral` (deepCoral → softCoral)

**Adaptive helpers**: `adaptiveBackground(for:)`, `adaptiveText(for:)`, `adaptiveCardBackground(for:)`, `adaptivePrimary(for:)` — always pass ColorScheme

## Config

- **Debug base URL**: `https://dev.studyreef.com` (Hetzner host machine port 8001 via Caddy)
- **Release base URL**: `https://api.studyreef.com` (Hetzner Docker production container)
- **UIAppFonts**: 9 font files (Quicksand x5, DynaPuff x4)
- **NSAppTransportSecurity**: allows insecure HTTP for local dev IPs
- **NSMicrophoneUsageDescription**: voice recording for study sessions
- **Supported orientations**: all 4 (portrait + landscape, iPad only)

## Key Frameworks

- **SwiftUI** + **SwiftData** — UI and persistence
- **PencilKit** — drawing (PKCanvasView)
- **PDFKit** + **Vision** — PDF reading + OCR
- **AuthenticationServices** — Apple Sign-In
- **AVFoundation** — voice recording
- **Security** — Keychain
- **SQLite3** — vector store (direct C API)
- **Accelerate** — SIMD vector math (cosine similarity)

## Testing

**Framework:** Swift Testing (`@Test`, `#expect`, `@Suite`)

**Run tests:** `xcodebuild -project Reef-iOS/Reef.xcodeproj -scheme Reef -destination 'platform=iOS Simulator,name=iPad Pro 11-inch (M4)' test 2>&1 | grep -E '(passed|failed|error:)'`

**Architecture:** Integration tests hit `localhost:8000` (real Reef-Server). Pure-logic unit tests need no server. Tests skip gracefully when server is unavailable via `IntegrationTestConfig.serverIsReachable()`.

**Test structure:**
```
ReefTests/
  Helpers/
    IntegrationTestHelpers.swift      — Server reachability check, test session helpers
    MockURLProtocol.swift             — URLProtocol stub (kept for future use)
  TextChunkerTests.swift              — 30 tests, pure logic (no server)
  ModelTests.swift                    — 37 tests, data model computed properties (no server)
  SSEParserTests.swift                — 11 tests, SSE line parsing (no server)
  AIServiceTests.swift                — 9 tests, real server embedding integration
  EmbeddingServiceTests.swift         — 12 tests, real server embedding + cosine similarity
  VectorStoreTests.swift              — 12 tests, SQLite with temp DB files (no server)
  RAGServiceTests.swift               — 9 tests, full RAG pipeline with real server + temp SQLite
  ServerAPITests.swift                — 8 tests, strokes/SSE/profile/session REST endpoints
  KeychainServiceTests.swift          — 5 tests, Keychain round-trip (no server)
  PreferencesTests.swift              — 5 tests, UserDefaults persistence (no server)
  FileStorageServiceTests.swift       — 4 tests, file I/O round-trip (no server)
```

**Key patterns:**
- No mock infrastructure — integration tests use real services with `AIService(baseURL: "http://localhost:8000")`
- DI: Services have `init(dep: ConcreteType = .shared)` — tests pass custom instances, prod uses defaults
- `@Suite(.serialized)` required for server-hitting tests and shared-state tests (Keychain, file storage)
- VectorStore tests use temp SQLite files (`FileManager.default.temporaryDirectory`)
- `nonisolated` on pure functions in actors (`isAvailable()`, `cosineSimilarity()`) for sync access
- TextChunker header regex only matches `chapter` or `CHAPTER` (not mixed case)
- Form feed `\u{000C}` is in `CharacterSet.newlines` — use `PAGE N` text pattern for page break tests
- Full test plan: `docs/plans/2026-02-19-comprehensive-test-plan.md` (parent repo)
