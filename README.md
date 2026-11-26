# Edged (Flutter & Dart — Android & iOS)

A 1:1 Flutter/Dart port of **Edged** from `edge.ai` — your private, offline on-device AI assistant.

## Features Implemented
- **Phone Biometric / Device PIN App Lock** (`local_auth` via `USE_BIOMETRIC`, enabled by default when a screen lock is configured) + optional local **Profile** (`Name`, `Phone`, `Email` in Settings via `flutter_secure_storage`).
- **7 On-Device Model Tiers** (Lite / Standard / Pro) with HuggingFace GGUF + `mmproj` downloads, device-aware **Best for Device** recommendation, pause/resume, auto-resume on foreground return, disk-full detection, `prompter_model_meta.json`, and 99%-size orphan self-healing.
- **5-Tab Navigation**: `Chats`, `Knowledge`, `Scan`, `Agents`, and `Settings` (with `/proactive` accessible from the Chats AppBar bell icon).
- **AI Chat + Offline Voice Mode** with SQLite persistence (`edge_chat.db` v4), auto-titling, last-10-message context trimming, live device context injection, on-device English Speech-to-Text (`speech_to_text`), sentence-buffered Text-to-Speech (`flutter_tts`), and real-time barge-in stop.
- **Offline Knowledge Base (RAG + Citations)**: Multi-document `.txt`, `.md`, `.docx`, and `.pdf` indexing (up to 10 MB) with chunking, SQLite persistence (`KnowledgeDocumentEntity`, `KnowledgeChunkEntity`), hybrid keyword/BM25 retrieval, structured answers, and inline `[filename §chunk]` source citations.
- **Offline Scan & Receipt OCR**: Camera & gallery image capture powered by on-device ML Kit Latin OCR (`google_mlkit_text_recognition`) feeding into `Qwen3.5` / `ChatEngine` for receipt totals, itemized lists, and text summaries.
- **Proactive Local Assistant (`/proactive`)**: On-device Daily Briefing generator (`OVERVIEW`, `HIGHLIGHTS`, `NEXT ACTIONS`), scheduled offline reminders (`ProactiveReminderEntity`), and 24-hour background briefings (`workmanager` + `flutter_local_notifications`).
- **Unified Agents + Agent-to-Agent (A2A) Chaining**: 12 predefined Agents (**Scheduled Email**, **Scheduled WhatsApp**, **Knowledge RAG**, **OCR & Receipt**, **Action & Reminder**, **Daily Briefing**, plus all 6 classic Skills: Summarizer, Translator, Code Explainer, Writing Assistant, Grammar Fixer, Brainstorm Helper), custom Agent builder (`CustomAgentEntity`), and multi-step A2A handoffs.
- **Android & iOS Native Channels** (`com.edgedai.app/device` for RAM/storage probing, notification permission requests, and `ACTION_OPEN_DOCUMENT` file-to-cache streaming).

## Getting Started

```bash
flutter pub get
flutter test
flutter run
```

> **Note on Native GGUF Inference**: On Android, `ChatEngine` uses `llama_flutter_android` (`llama.cpp`) for on-device GGUF inference, and falls back to an offline preview streamer on platforms without a linked native backend.

## Android Packaging (`android-pack.ps1`)

Use [android-pack.ps1](android-pack.ps1) on Windows PowerShell to build signed Android packages into `dist/`:

```powershell
# Build signed release APK -> dist\Edged-v1.0.0-release.apk
.\android-pack.ps1

# Build signed release APK + Play Store AAB -> dist\Edged-v1.0.0-release.aab
.\android-pack.ps1 -AppBundle

# Build signed release APK, install via ADB, and launch on connected phone
.\android-pack.ps1 -Install

# Build debug APK -> dist\Edged-debug.apk (can combine with -Install)
.\android-pack.ps1 -Debug
.\android-pack.ps1 -Debug -Install
```

### Flags
- `-Debug`: Builds a debug APK instead of a release APK.
- `-Install`: Runs `adb install -r` on the built APK and launches `com.edgedai.app/.MainActivity`.
- `-AppBundle`: Also runs `flutter build appbundle --release` and copies `dist\Edged-v1.0.0-release.aab` for Google Play Store upload (ignored when `-Debug` is set).

### Release Signing
Release builds (`APK` and `AAB`) are signed using `android/key.properties` (pointing to `android/upload-keystore.jks`) when present, or fall back to the debug keystore if `android/key.properties` is missing.

## Open-Source Libraries & Credits

### On-Device AI, Voice, OCR & Background
- **`llama_flutter_android`** (`llama.cpp` Android bindings) — On-device GGUF LLM inference
- **`speech_to_text`** — On-device English Speech-to-Text
- **`flutter_tts`** — Local Text-to-Speech synthesis
- **`google_mlkit_text_recognition`** — On-device ML Kit Latin OCR for Scan & Receipt Q&A
- **`workmanager`** — Offline periodic background tasks
- **`flutter_local_notifications`** — Local reminder & daily briefing notifications

### Storage, Networking, Documents & Platform
- **`flutter_riverpod`** — State management & dependency injection
- **`go_router`** — Declarative navigation & route guards
- **`sqflite`**, **`path`**, **`path_provider`** — Local SQLite database (`edge_chat.db`) & file paths
- **`local_auth`** — Phone biometric & device PIN/pattern App Lock
- **`flutter_secure_storage`** — Encrypted local App Lock & optional Profile storage
- **`dio`** — Resumable HTTP model downloads (`.part` Range support)
- **`syncfusion_flutter_pdf`** — Offline PDF text extraction *(Syncfusion Community License)*
- **`archive`**, **`xml`** — Offline `.docx` (`word/document.xml`) extraction
- **`file_picker`**, **`image_picker`** — Document & Photo Picker / camera integration
- **`device_info_plus`**, **`battery_plus`**, **`wakelock_plus`** — Device RAM/battery probing & download wakelock
- **`google_fonts`**, **`intl`**, **`uuid`**, **`url_launcher`**, **`cupertino_icons`** — Typography, formatting, IDs, links & icons

### Open-Weight Models (User-Downloaded)
- **Qwen3.5** (Alibaba / Unsloth & ggml-org GGUF quantizations)
- **Phi-4-mini** (Microsoft / Unsloth GGUF quantization)
- **Gemma 3n** (Google / Unsloth GGUF quantizations)
