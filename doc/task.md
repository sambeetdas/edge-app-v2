# Task & Implementation Tracker — Edged (Flutter)

## Legend
- `[x]` Implemented in codebase
- `[ ]` Pending verification / external environment action

---

## 1. Project & Native Platform Setup
- [x] `pubspec.yaml` with Riverpod, GoRouter, sqflite, Dio, flutter_secure_storage, file_picker, image_picker, archive, xml, syncfusion_flutter_pdf, device_info_plus, battery_plus, wakelock_plus, url_launcher, google_fonts
- [x] `analysis_options.yaml` and `.gitignore`
- [x] Android `AndroidManifest.xml`, `build.gradle.kts` (`com.edgedai.app`, `minSdk = 24`), `styles.xml`, `MainActivity.kt` (`com.edgedai.app/device`)
- [x] iOS `Info.plist` (`com.edgedai.app`, iOS 15.0, camera/photo permissions) and `AppDelegate.swift` (`com.edgedai.app/device`)

## 2. Core Theme & Branding
- [x] `lib/core/theme/app_colors.dart` (Edged light/dark palettes, brand gradient, bubble colors)
- [x] `lib/core/theme/app_theme.dart` (Material 3 light & dark themes)
- [x] `lib/core/widgets/edged_logo.dart` (CustomPainter geometric "E" chevron logo)
- [x] `lib/core/utils/formatters.dart` (byte formatting, relative dates, markdown stripping)

## 3. On-Device AI Engine (`lib/engine/`)
- [x] `lib/engine/models/prompt_format.dart` (`ChatML`, `Gemma`, `Phi3`, anti-prompts, `/no_think`)
- [x] `lib/engine/models/model_tier.dart` (all 7 tiers with exact URLs, sizes, RAM, context, flags)
- [x] `lib/engine/models/chat_models.dart` (`ChatMessage`, `ChatRequest`, `ModelOptions`, `DownloadProgress`, `DownloadedModelInfo`, `SkillDefinition`)
- [x] `lib/engine/services/model_manager.dart` (Dio resumable download, wakelock, disk-full handling, metadata + 99% orphan healing)
- [x] `lib/engine/services/chat_engine.dart` (single-flight mutex, anti-prompt buffer, `com.edgedai.app/llama` channel + offline fallback)
- [x] `lib/engine/services/skills_engine.dart` (6 built-in skills)
- [x] `lib/engine/services/vision_engine.dart` (image Q&A prompt + mmproj check)

## 4. Data & Persistence (`lib/data/` & `lib/providers/`)
- [x] `lib/data/database/app_database.dart` (`edge_chat.db` with 4 tables)
- [x] `lib/data/services/auth_service.dart` (25 countries, local 6-digit OTP, 30-day session)
- [x] `lib/data/services/chat_history_service.dart`
- [x] `lib/data/services/custom_skills_service.dart`
- [x] `lib/data/services/games_service.dart` (9 built-in games + custom games CRUD)
- [x] `lib/data/services/document_service.dart` (`.txt`, `.md`, `.docx`, `.pdf` extraction + token truncation)
- [x] `lib/data/services/device_service.dart` (RAM/storage compatibility + device context string)
- [x] `lib/providers/app_providers.dart` & `lib/providers/model_loader_helper.dart`

## 5. UI Features & Navigation (`lib/features/`, `lib/app.dart`, `lib/main.dart`)
- [x] `LoadingScreen`, `PhoneSignInScreen`, `OtpVerificationScreen`
- [x] `MainShellScreen` (capability-gated bottom navigation)
- [x] `ChatListScreen`, `ChatScreen`, `ChatBubbleWidget`
- [x] `SkillsScreen`, `SkillExecutionScreen`, `CreateSkillScreen`
- [x] `ImageQaScreen` & `DocumentQaScreen`
- [x] `GamesScreen`, `GamePlayScreen`, `CreateGameScreen`
- [x] `SettingsScreen`, `ModelSelectionScreen`, `ModelDownloadScreen`

## 6. Tests & Pending Verification
- [x] `test/edged_core_test.dart` (unit tests for `ModelTier`, `PromptFormat`, built-in skills/games/countries)
- [x] `test/services_unit_test.dart` (unit tests for `DocumentService`, `DeviceCompatibilityReport`, `PromptFormat`, `ChatEngine`)
- [x] `integration_test/app_e2e_test.dart` (full E2E flow: Auth → Model Download → Chat → Skills → Word Chain Game → Settings & Sign Out)
- [ ] Install Flutter SDK on build machine and run `flutter pub get`
- [ ] Run `flutter analyze`, `flutter test`, and `flutter test integration_test/app_e2e_test.dart`
- [ ] Run `flutter run` on Android / iOS device or emulator
- [ ] Optional: Bundle native `llama.cpp` AAR (Android) and XCFramework (iOS) on `com.edgedai.app/llama` for full hardware GGUF inference
