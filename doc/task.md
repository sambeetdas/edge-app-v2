# Task & Implementation Tracker — Edged (Flutter)

## Legend
- `[x]` Implemented in codebase
- `[ ]` Pending verification / external environment action

---

## 1. Project & Native Platform Setup
- [x] `pubspec.yaml` with Riverpod, GoRouter, sqflite, Dio, flutter_secure_storage, file_picker, image_picker, archive, xml, syncfusion_flutter_pdf, device_info_plus, battery_plus, wakelock_plus, url_launcher, google_fonts, flutter_tts, speech_to_text, google_mlkit_text_recognition, flutter_local_notifications, workmanager, local_auth
- [x] `analysis_options.yaml` and `.gitignore`
- [x] Android `AndroidManifest.xml` (`RECORD_AUDIO`, `USE_BIOMETRIC`, speech/TTS `<queries>`), `build.gradle.kts` (`com.edgedai.app`, `compileSdk = 37`, `minSdk = 26`, core library desugaring), `proguard-rules.pro`, `MainActivity.kt` (`FlutterFragmentActivity`, `com.edgedai.app/device`)
- [x] iOS `Info.plist` (`com.edgedai.app`, iOS 15.0, camera/photo permissions) and `AppDelegate.swift` (`com.edgedai.app/device`)

## 2. Core Theme & Branding
- [x] `lib/core/theme/app_colors.dart` (Edged light/dark palettes, brand gradient, bubble colors)
- [x] `lib/core/theme/app_theme.dart` (Material 3 light & dark themes)
- [x] `lib/core/widgets/edged_logo.dart` (CustomPainter geometric "E" chevron logo)
- [x] `lib/core/widgets/structured_response_card.dart` (structured section cards for Scan, Knowledge, and Daily Briefing)
- [x] `lib/core/utils/formatters.dart` (byte formatting, relative dates, markdown stripping)

## 3. On-Device AI Engine (`lib/engine/`)
- [x] `lib/engine/models/prompt_format.dart` (`ChatML`, `Gemma`, `Phi3`, anti-prompts, `/no_think`)
- [x] `lib/engine/models/model_tier.dart` (all 7 tiers with exact URLs, sizes, RAM, context, flags)
- [x] `lib/engine/models/chat_models.dart` (`ChatMessage`, `ChatRequest`, `ModelOptions`, `DownloadProgress`, `DownloadedModelInfo`, `SkillDefinition`)
- [x] `lib/engine/services/model_manager.dart` (Dio resumable download, wakelock, disk-full handling, metadata + 99% orphan healing)
- [x] `lib/engine/services/chat_engine.dart` (single-flight mutex, anti-prompt buffer, `llama_flutter_android` + offline fallback)
- [x] `lib/engine/services/skills_engine.dart` (6 built-in skills)
- [x] `lib/engine/services/vision_engine.dart` (offline ML Kit Latin OCR + `ChatEngine` Q&A)
- [x] `lib/engine/services/voice_service.dart` (on-device English STT + `flutter_tts` with barge-in)
- [x] `lib/engine/services/agent_orchestrator.dart` (sequential A2A handoffs, RAG/OCR/Email/WhatsApp/Reminder tool execution)

## 4. Data & Persistence (`lib/data/` & `lib/providers/`)
- [x] `lib/data/database/app_database.dart` (`edge_chat.db` v4 with 10 tables including Knowledge, Proactive, and Agent entities)
- [x] `lib/data/services/auth_service.dart` (phone biometric/PIN App Lock via `local_auth` + optional local `UserProfile`)
- [x] `lib/data/services/chat_history_service.dart`
- [x] `lib/data/services/agent_service.dart` (12 predefined Agents + custom SQLite Agents + A2A message logs)
- [x] `lib/data/services/games_service.dart` (9 built-in games + custom games CRUD)
- [x] `lib/data/services/document_service.dart` (`.txt`, `.md`, `.docx`, `.pdf` extraction, chunking, token truncation)
- [x] `lib/data/services/knowledge_service.dart` (multi-doc SQLite RAG + hybrid keyword/BM25 retrieval + citations)
- [x] `lib/data/services/proactive_service.dart` (`workmanager` 24h daily briefing + `flutter_local_notifications` reminders)
- [x] `lib/data/services/device_service.dart` (RAM/storage compatibility + device context string)
- [x] `lib/providers/app_providers.dart` & `lib/providers/model_loader_helper.dart`

## 5. UI Features & Navigation (`lib/features/`, `lib/app.dart`, `lib/main.dart`)
- [x] `LoadingScreen` (phone biometric/PIN unlock gate on launch)
- [x] `MainShellScreen` (5-tab navigation: `Chats`, `Knowledge`, `Scan`, `Agents`, `Settings`)
- [x] `ChatListScreen`, `ChatScreen` (voice reply + mic + barge-in), `ChatBubbleWidget`
- [x] `DocumentQaScreen` (Knowledge Base with multi-doc RAG & source citations)
- [x] `ImageQaScreen` (Scan & Receipt OCR with ML Kit + quick-action chips)
- [x] `ProactiveScreen` (`/proactive`: Daily Briefing + Smart Reminders)
- [x] `AgentsScreen`, `AgentRunScreen` (live A2A step cards + Email/WhatsApp actions), `CreateAgentScreen`
- [x] `SettingsScreen` (App Lock toggle + optional local Profile), `ModelSelectionScreen` (device-aware `Best for Device` pick), `ModelDownloadScreen` (auto-resume on foreground return)
- [x] `dist/play_store_assets/` (512x512 icon, 1024x500 feature graphic, phone screenshots, store listing copy; untracked) & Play Store Closed Alpha `1.0.0+4` bundle

## 6. Tests & Verification
- [x] `test/edged_core_test.dart` (unit tests for `ModelTier`, `PromptFormat`, built-in skills/games/countries)
- [x] `test/services_unit_test.dart` (unit tests for `DocumentService` including `chunkText`, `DeviceCompatibilityReport`, `PromptFormat`, `ChatEngine`)
- [x] `integration_test/app_e2e_test.dart`
- [x] `dart analyze --no-fatal-warnings` (0 errors) & `flutter test --no-pub` (12/12 passed)
- [x] Signed release APK + AAB built via `.\android-pack.ps1 -AppBundle` and verified on physical Android device (`ZD222XK2FC`)
