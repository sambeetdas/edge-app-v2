# Edged (Flutter & Dart — Android & iOS)

A 1:1 Flutter/Dart port of **Edged** (`Edge.App` + `Prompter.AI.Edge`) from `edge.ai` — your private, offline on-device AI assistant.

## Features Implemented
- **Phone + Local OTP Auth** (`com.edgedai.app`) with 25-country autocomplete picker and 30-day secure session (`flutter_secure_storage`).
- **7 On-Device Model Tiers** (Lite / Standard / Pro) with HuggingFace GGUF + `mmproj` downloads, pause/resume, disk-full detection, `prompter_model_meta.json`, and 99%-size orphan self-healing.
- **Capability-Gated Navigation**: `Chats`, `Agent Skills`, `Image Q&A` (vision tiers), `Docs Q&A` (`maxContextTokens >= 2048`), `AI Games`, and `Settings`.
- **AI Chat** with SQLite persistence (`edge_chat.db`), auto-titling, last-10-message context trimming, live device context injection, 10s "Still thinking…" indicator, and 120s timeout.
- **6 Built-in Skills + Custom Skill Builder** (Summarizer, Translator, Code Explainer, Writing Assistant, Grammar Fixer, Brainstorm Helper).
- **9 Built-in AI Games + Custom Game Builder** (20 Questions, Riddle Me This, Text Adventure, Trivia Challenge, Story Builder, Word Chain, Word Game, Who Am I?, Debate Club) with word-game validation and retry support.
- **Document Q&A** (`.txt`, `.md`, `.docx`, `.pdf` up to 10 MB, 4 chars/token, 750 reserved tokens, truncation warning).
- **Image Q&A** (camera & gallery picker).
- **Android & iOS Native Channels** (`com.edgedai.app/device` for RAM & free storage probing).

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
