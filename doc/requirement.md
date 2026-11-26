# System & Product Requirements — Edged (Flutter)

## 1. Functional Requirements

### FR-1: Device Authentication & Optional Profile
- **FR-1.1**: On launch (`LoadingScreen`), prompt the phone's native authentication (`local_auth` with `biometricOnly: false` for fingerprint, face unlock, or device PIN/pattern) when `App Lock` is enabled (enabled by default if a screen lock is configured).
- **FR-1.2**: Gracefully allow access if no screen lock is configured on the device (`isDeviceLockSupported() == false`) so unlocked test/review devices are not blocked.
- **FR-1.3**: Users can toggle **App Lock** and trigger **Lock App** from `SettingsScreen`.
- **FR-1.4**: Users can optionally save local-only **Name**, **Phone**, and **Email** (`UserProfile`) in `SettingsScreen`, persisted in `FlutterSecureStorage`.

### FR-2: Model Management & Compatibility
- **FR-2.1**: Display all 7 `ModelTier.availableTiers` grouped by `Lite`, `Standard`, and `Pro`, dynamically highlighting **`Best for Device`** based on usable RAM and free storage (`ModelSelectionScreen`).
- **FR-2.2**: Probe device RAM and available storage via `MethodChannel('com.edgedai.app/device')`. Enforce 1.5 GB OS RAM headroom (`effectiveRamGb = totalRamGb - 1.5`) and 200 MB storage buffer.
- **FR-2.3**: Stream model and optional `mmproj` downloads from HuggingFace using `Dio` with `.part` resume support, `WakelockPlus`, pause/cancel, automatic resume on `AppLifecycleState.resumed`, and disk-full error classification.
- **FR-2.4**: Persist `prompter_model_meta.json` and self-heal missing/corrupt metadata if a known GGUF file exists at `>= 99%` of expected size.

### FR-3: Shell Navigation
- **FR-3.1**: `Settings` is always visible (`MainShellScreen`).
- **FR-3.2**: `Chats`, `Knowledge`, `Scan`, and `Agents` tabs unlock when a model is downloaded.
- **FR-3.3**: `/proactive` (`ProactiveScreen`) is accessible from the `Chats` AppBar.

### FR-4: AI Chat & Offline Voice Mode
- **FR-4.1**: Create, list, swipe-delete, and auto-title chat sessions in SQLite (`edge_chat.db` v3).
- **FR-4.2**: Stream tokens via `llama_flutter_android` with ~80 ms UI throttling, 10s "Still thinking…" indicator, 120s timeout, and user-triggered Stop.
- **FR-4.3**: Trim conversation history to fit context budget and enrich the system prompt with live device info (`DeviceService.buildDeviceContextString`).
- **FR-4.4**: Support on-device English Speech-to-Text (`speech_to_text` with `onDevice: true`), sentence-buffered local Text-to-Speech (`flutter_tts`), and real-time barge-in cancellation (`VoiceService`).

### FR-5: Unified Agents & Agent-to-Agent (A2A) Chaining
- **FR-5.1**: Provide 12 predefined Agents: 6 automation/tool Agents (`scheduled_email`, `scheduled_whatsapp`, `rag_researcher`, `ocr_extractor`, `action_reminder`, `daily_briefing`) and 6 classic skill Agents (`summarizer`, `translator`, `code_explainer`, `writing_assistant`, `grammar_fixer`, `brainstorm`).
- **FR-5.2**: Support creating and deleting custom Agents in `CustomAgentEntity` (SQLite) with selectable tools (`llm`, `rag`, `ocr`, `email`, `whatsapp`, `reminder`) and optional default A2A handoff (`NextAgentId`), while preserving legacy `CustomSkillEntity` rows.
- **FR-5.3**: Support sequential A2A handoff chains (`AgentOrchestrator`, max 4 hops) persisted in `AgentRunEntity` / `AgentMessageEntity`, with scheduled Email (`mailto:`) and WhatsApp (`wa.me`) action notifications.

### FR-6: Offline Knowledge Base (RAG + Citations)
- **FR-6.1**: Support `.txt`, `.md`, `.docx` (ZIP `word/document.xml` parsing), and `.pdf` (text extraction via `syncfusion_flutter_pdf`) up to 10 MB, streamed via `ACTION_OPEN_DOCUMENT` to a local cache file on Android.
- **FR-6.2**: Chunk documents (`DocumentService.chunkText`), persist chunks in `KnowledgeDocumentEntity` / `KnowledgeChunkEntity`, retrieve top matching chunks (`KnowledgeService.searchChunks`), and display structured answers (`StructuredResponseCard`) with inline `[filename §chunk]` citations.

### FR-7: Scan & Receipt OCR
- **FR-7.1**: Allow camera capture and Android Photo Picker selection via `image_picker` (without `READ_MEDIA_IMAGES`), extract text offline via `google_mlkit_text_recognition`, and stream structured answers (`SUMMARY` / `DETAILS`) via `VisionEngine` + `ChatEngine`.

### FR-8: Proactive Local Assistant
- **FR-8.1**: Generate structured on-device Daily Briefings (`OVERVIEW`, `HIGHLIGHTS`, `NEXT ACTIONS`) from local chats, Knowledge Base docs, and pending reminders.
- **FR-8.2**: Schedule and manage offline local reminders (`ProactiveReminderEntity`, `flutter_local_notifications`) and optional 24-hour periodic briefings (`workmanager`).

## 2. Non-Functional Requirements
- **NFR-1 (Privacy / Offline-First)**: Zero network calls except user-initiated HuggingFace model downloads.
- **NFR-2 (Concurrency)**: Single-flight mutex in `ChatEngine` serializes model load, unload, and generation.
- **NFR-3 (Platform Support)**: Android API 26+ (`minSdk = 26`, `compileSdk = 37`, core library desugaring) and iOS 15.0+ (`arm64`).
- **NFR-4 (UI/UX)**: Material 3 light & dark themes, structured response cards, responsive layouts, and clipboard copy on AI responses.
