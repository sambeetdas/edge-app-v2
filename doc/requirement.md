# System & Product Requirements — Edged (Flutter)

## 1. Functional Requirements

### FR-1: Authentication & Session Management
- **FR-1.1**: Users sign in via country code + phone number (`PhoneSignInScreen`), with autocomplete and modal search across 25 countries (`AuthService.allCountries`).
- **FR-1.2**: Local 6-digit OTP (`100000`–`999999`) is generated and stored in `FlutterSecureStorage` (`auth_otp`, `auth_phone`), and displayed in a local demo banner on `OtpVerificationScreen`.
- **FR-1.3**: Successful OTP verification stores a UUID session token (`auth_token`) and 30-day UTC expiry (`auth_expiry`) and deletes the single-use OTP.
- **FR-1.4**: Sign-out clears all secure storage keys and unloads any loaded model.

### FR-2: Model Management & Compatibility
- **FR-2.1**: Display all 7 `ModelTier.availableTiers` grouped by `Lite`, `Standard`, and `Pro`, highlighting `qwen25-vl-3b` as `Recommended`.
- **FR-2.2**: Probe device RAM and available storage via `MethodChannel('com.edgedai.app/device')`. Enforce 1.5 GB OS RAM headroom (`effectiveRamGb = totalRamGb - 1.5`) and 200 MB storage buffer.
- **FR-2.3**: Stream model and optional `mmproj` downloads from HuggingFace using `Dio` with `.part` resume support, `WakelockPlus`, pause/cancel, and disk-full error classification.
- **FR-2.4**: Persist `prompter_model_meta.json` and self-heal missing/corrupt metadata if a known GGUF file exists at `>= 99%` of expected size.

### FR-3: Capability-Gated Shell Navigation
- **FR-3.1**: `Settings` is always visible (`MainShellScreen`).
- **FR-3.2**: `Chats`, `Skills`, and `Games` tabs appear only when a model is downloaded.
- **FR-3.3**: `Image` tab appears only when `tier.supportsVision == true`.
- **FR-3.4**: `Docs` tab appears only when `tier.supportsDocumentQa == true` (`maxContextTokens >= 2048`).

### FR-4: AI Chat
- **FR-4.1**: Create, list, swipe-delete, and auto-title chat sessions (first user message truncated to 40 chars + `...`) in SQLite (`edge_chat.db`).
- **FR-4.2**: Stream tokens with ~80 ms UI throttling, 10s "Still thinking…" indicator, 120s timeout, and user-triggered Stop.
- **FR-4.3**: Trim conversation history to the last 10 messages and enrich the system prompt with live device info (`DeviceService.buildDeviceContextString`).

### FR-5: Agent Skills
- **FR-5.1**: Provide 6 built-in skills (`summarizer`, `translator`, `code_explainer`, `writing_assistant`, `grammar_fixer`, `brainstorm`).
- **FR-5.2**: Support creating and deleting custom skills in `CustomSkillEntity` (SQLite), with `maxTokens = 1024` for custom skills and `512` for built-in skills.

### FR-6: Document Q&A
- **FR-6.1**: Support `.txt`, `.md`, `.docx` (ZIP `word/document.xml` parsing), and `.pdf` (text extraction via `syncfusion_flutter_pdf`).
- **FR-6.2**: Reject files `> 10 MB` and scanned/empty-text documents.
- **FR-6.3**: Truncate extracted text to `(modelMaxContextTokens - 750) * 4` chars (min 256 tokens) and display a truncation/usage banner.

### FR-7: Image Q&A
- **FR-7.1**: Allow camera capture and gallery selection via `image_picker` and stream answers via `VisionEngine`.

### FR-8: AI Games
- **FR-8.1**: Provide 9 built-in games (`20-questions`, `riddle-me-this`, `text-adventure`, `trivia-challenge`, `story-builder`, `word-chain`, `word-game`, `who-am-i`, `debate-club`) + custom game builder (`CustomGameEntity`).
- **FR-8.2**: Inject pacing directives on turns 3, 6, 10, and 15 when `usePhaseDirectives == true`.
- **FR-8.3**: For `GameInputMode.word`, enforce single-alphabetic-word input and starting-letter matching parsed from `next starts with [A-Za-z]`, capping `maxTokens = 50` except on `"stop"` / `"i give up"`.

## 2. Non-Functional Requirements
- **NFR-1 (Privacy / Offline-First)**: Zero network calls except user-initiated HuggingFace model downloads.
- **NFR-2 (Concurrency)**: Single-flight mutex in `ChatEngine` serializes model load, unload, and generation.
- **NFR-3 (Platform Support)**: Android API 24+ (`minSdk = 24`, `largeHeap = true`) and iOS 15.0+ (`arm64`).
- **NFR-4 (UI/UX)**: Material 3 light & dark themes, responsive layouts, accessible contrast, and clipboard copy on AI responses.
