# Step-by-Step Build Guide — Building **Edged** from Scratch

> **Audience**: Junior Flutter / Android developers.  
> **Goal**: Walk through how to build a **100% offline on-device AI assistant** (Chat, Voice, Knowledge Base RAG, Receipt/Image OCR, Proactive Reminders, and Skills) from scratch, explaining **why** each library and design pattern was chosen.

---

## Part 1: Why Each Library & Design Decision Was Chosen

### Why Flutter & Dart?
- **Single Codebase for Android & iOS**: One Dart codebase drives both platforms with near-native ARM64 AOT performance and smooth 60–120 fps streaming UI (`ListView`, `CustomPainter`, Material 3).
- **Clean Native Interop**: Flutter's `MethodChannel` (`com.edgedai.app/device`) and plugin ecosystem (`llama_flutter_android`, `google_mlkit_text_recognition`, `speech_to_text`) make it straightforward to run C++/Kotlin/Swift code for RAM probing, GGUF inference, and document streaming while keeping all business logic in Dart.
- **Fast Iteration & Testing**: Hot reload speeds up UI polish, and pure-Dart services (`DocumentService`, `KnowledgeService`, `PromptFormat`) can be unit-tested in milliseconds with `flutter test`.

Before writing code, it helps to understand **why** this stack works cleanly together on mobile:

| Area | Library / Approach Chosen | Why We Chose It (and What We Avoided) |
|---|---|---|
| **Local LLM Inference** | `llama_flutter_android` | Wraps `llama.cpp` for Android so quantized `.gguf` models (`Qwen3.5`, `Phi-4-mini`, `Gemma 3n`) run 100% on-device with token streaming. Wrapped behind `ChatEngine` with a `Future` mutex so two prompts never collide in native memory. |
| **State & DI** | `flutter_riverpod` | Compile-safe providers (`chatEngineProvider`, `modelManagerProvider`, `knowledgeServiceProvider`) make it easy to share singletons and refresh UI state when a model finishes downloading. |
| **Navigation** | `go_router` | Clean declarative routes (`/loading`, `/home`, `/proactive`, `/models/download/:tierId`) with startup device-unlock gating. |
| **Local Database** | `sqflite` (`edge_chat.db` v3) | Zero-config embedded SQLite for chats, custom skills, indexed RAG chunks, and scheduled reminders. We create tables in **both** `onUpgrade` and `onOpen` (`CREATE TABLE IF NOT EXISTS`) so schema upgrades never crash existing installs. |
| **Device Auth & Profile** | `local_auth` + `flutter_secure_storage` | Uses the phone's native fingerprint, face unlock, or device PIN (`FlutterFragmentActivity` + `USE_BIOMETRIC`) instead of a custom login wall, and encrypts App Lock preference + optional local Profile (`Name`, `Phone`, `Email`) on-device. |
| **Model Downloads** | `dio` + `wakelock_plus` | Supports HTTP `Range` headers so large 0.5–5.3 GB `.gguf` files resume from `.part` files if interrupted. `WakelockPlus` keeps the CPU/screen awake while downloading, and `ModelDownloadScreen` auto-resumes when the app returns to foreground (`AppLifecycleState.resumed`). |
| **Offline Voice Mode** | `speech_to_text` (`onDevice: true`) + `flutter_tts` | **Crucial native reason**: Adding a separate `whisper.cpp` Flutter plugin alongside `llama_flutter_android` can cause duplicate `libggml.so` native symbol collisions and bloat the APK. Android's built-in offline `SpeechRecognizer` + `flutter_tts` keeps the APK small and avoids `.so` conflicts. |
| **Offline OCR** | `google_mlkit_text_recognition` | Runs ML Kit's bundled on-device Latin OCR model (`TextRecognitionScript.latin`) in ~200 ms with zero network calls, then feeds the extracted text into `Qwen3.5` for receipt/document Q&A. (Optional Chinese/Devanagari/Japanese/Korean classes are excluded from bundling and silenced in `proguard-rules.pro`.) |
| **Document Parsing** | `syncfusion_flutter_pdf` + `archive` + `xml` | Pure Dart packages: `syncfusion_flutter_pdf` extracts text from PDFs, and `archive` + `xml` unzips `.docx` and reads `word/document.xml`. |
| **Android File Picking** | Native `ACTION_OPEN_DOCUMENT` -> temp cache file | Passing large PDF bytes over Flutter's `MethodChannel` hits Android's **1 MB Binder limit** (`TransactionTooLargeException`). Streaming the URI to `cacheDir` and returning the file path avoids that crash completely. |
| **Proactive Assistant** | `workmanager` + `flutter_local_notifications` | Schedules offline reminders and 24-hour background briefings without Firebase/FCM. Requires `compileSdk = 37` and Java 8+ core library desugaring. |
| **Play Store Compliance** | System Photo Picker (`image_picker` without `READ_MEDIA_IMAGES`) & no `FOREGROUND_SERVICE_DATA_SYNC` | Google Play rejects broad `READ_MEDIA_IMAGES` permissions for occasional photo picking and requires video reviews for `DATA_SYNC` foreground services. Using Android's Photo Picker + `WakelockPlus` resumable downloads avoids both blockers. |

---

## Part 2: Step-by-Step Build Instructions

### Step 1 — Create the Project & Add Dependencies
1. Create a new Flutter project:
   ```bash
   flutter create --org com.edgedai --project-name edged edge_app
   cd edge_app
   ```
2. Add the dependencies to `pubspec.yaml`:
   ```yaml
   dependencies:
     flutter:
       sdk: flutter
     flutter_riverpod: ^3.5.0
     go_router: ^18.1.4
     sqflite: ^2.4.1
     path: ^1.9.0
     path_provider: ^2.1.5
     flutter_secure_storage: ^11.2.0
     dio: ^5.7.0
     file_picker: ^13.4.0
     image_picker: ^1.1.2
     archive: ^4.7.1
     xml: ^7.1.0
     syncfusion_flutter_pdf: ^35.2.12
     device_info_plus: ^13.3.0
     battery_plus: ^7.1.2
     wakelock_plus: ^1.2.8
     url_launcher: ^6.3.1
     uuid: ^4.5.1
     intl: ^0.20.3
     google_fonts: ^8.0.2
     llama_flutter_android: ^0.2.6
     flutter_tts: ^4.2.5
     speech_to_text: ^7.5.0
     google_mlkit_text_recognition: ^1.0.3
     flutter_local_notifications: ^23.0.4
     workmanager: ^0.10.10
     local_auth: ^3.0.2
   ```
3. Run `flutter pub get`.

---

### Step 2 — Configure Android Native Layer (`android/app/`)
1. **`android/app/build.gradle.kts`**:
   - Set `compileSdk = 37` and `minSdk = 26` (needed by `flutter_local_notifications` and modern ML Kit / native inference).
   - Enable Java 8+ core library desugaring inside `compileOptions`:
     ```kotlin
     compileOptions {
         isCoreLibraryDesugaringEnabled = true
         sourceCompatibility = JavaVersion.VERSION_17
         targetCompatibility = JavaVersion.VERSION_17
     }
     ```
   - Add the desugaring dependency at the bottom:
     ```kotlin
     dependencies {
         coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
     }
     ```
2. **`android/app/proguard-rules.pro`**:
   - Keep `llama_flutter_android` and ML Kit classes so R8 release minification doesn't strip reflection constructors (`NullPointerException` in `zzmj.<init>`):
     ```proguard
     -keep class com.write4me.llama_flutter_android.** { *; }
     -keep class com.google.mlkit.** { *; }
     -keep class com.google.android.gms.internal.mlkit_** { *; }
     -keep class com.google.firebase.components.** { *; }
     -dontwarn com.google.mlkit.vision.text.chinese.**
     -dontwarn com.google.mlkit.vision.text.devanagari.**
     -dontwarn com.google.mlkit.vision.text.japanese.**
     -dontwarn com.google.mlkit.vision.text.korean.**
     ```
3. **`android/app/src/main/AndroidManifest.xml`**:
   - Declare `INTERNET`, `WAKE_LOCK`, `POST_NOTIFICATIONS`, `RECORD_AUDIO`, `USE_BIOMETRIC`, `CAMERA`.
   - Extend `FlutterFragmentActivity` in `MainActivity.kt` (required by `local_auth` / `BiometricPrompt`).
   - Explicitly strip `READ_MEDIA_IMAGES` and `READ_MEDIA_VIDEO` using `tools:node="remove"` so plugins cannot merge them.
   - Add `<queries>` for `android.speech.RecognitionService` and `android.intent.action.TTS_SERVICE` (required on Android 11+ for STT/TTS discovery).
4. **`android/app/src/main/kotlin/com/edgedai/app/MainActivity.kt`**:
   - Expose `MethodChannel("com.edgedai.app/device")` with:
     - `getSystemMemoryBytes` (`ActivityManager.MemoryInfo.totalMem`)
     - `getAvailableStorageBytes` (`StatFs.availableBytes`)
     - `requestNotificationPermission` (`POST_NOTIFICATIONS` on Android 13+)
     - `pickDocument`: opens `Intent.ACTION_OPEN_DOCUMENT` with `FLAG_GRANT_READ_URI_PERMISSION`, falls back across `openInputStream` / `openAssetFileDescriptor` / `openTypedAssetFileDescriptor`, infers missing extensions from MIME type, streams up to 10 MB to `File.createTempFile(..., cacheDir)`, and returns `{"name": name, "path": filePath}`.

---

### Step 3 — Core Theme, Logo & Shared Response Card (`lib/core/`)
1. **`app_colors.dart` & `app_theme.dart`**: Define Material 3 light & dark palettes (`brandPurpleDeep` → `brandPurpleMid` → `brandBlue` gradient) and rounded `CardThemeData` / `InputDecorationTheme`.
2. **`edged_logo.dart`**: Draw the geometric "E" chevron emblem using `CustomPainter` so the logo scales sharply at any size.
3. **`formatters.dart`**: Add byte formatting (`formatBytes`), relative dates (`formatRelativeDate`), and `stripMarkdown` (removes `<think>...</think>` reasoning blocks and raw markdown symbols).
4. **`structured_response_card.dart`**: Build one reusable widget (`StructuredResponseCard`) used by **Scan**, **Knowledge**, and **Daily Briefing**. It parses plain-text section headers (`OVERVIEW`, `SUMMARY`, `DETAILS`, `ANSWER`, `KEY POINTS`, `HIGHLIGHTS`, `NEXT ACTIONS`), renders `•` bullets with accent dots, bolds `Key: Value` pairs, and adds a one-tap **Copy** button.

---

### Step 4 — Local Database (`lib/data/database/app_database.dart`)
Create a singleton `AppDatabase` managing `edge_chat.db` at `version: 3` with 7 tables:
- `ChatSessionEntity` & `ChatMessageEntity` (indexed on `SessionId`)
- `CustomSkillEntity` & `CustomGameEntity`
- `KnowledgeDocumentEntity` & `KnowledgeChunkEntity` (indexed on `DocumentId`)
- `ProactiveReminderEntity`

**Important pattern**: Call `_createKnowledgeTables(db)` and `_createProactiveTables(db)` (using `CREATE TABLE IF NOT EXISTS`) in **both** `onUpgrade` and `onOpen` so older user databases never hit missing-table errors.

---

### Step 5 — AI Engine & Model Downloads (`lib/engine/`)
1. **`model_tier.dart`**: Define all 7 GGUF tiers (`qwen35-0.8b`, `qwen35-2b`, `phi4-mini`, `gemma3n-e2b`, `qwen35-4b`, `gemma3n-e4b`, `qwen35-9b`) with their HuggingFace URLs, byte sizes, RAM requirements, context sizes, and `PromptFormat`.
2. **`prompt_format.dart`**: Format conversations for `ChatML`, `Gemma`, and `Phi3` templates, appending `/no_think` when `suppressThinkingMode` is enabled.
3. **`model_manager.dart`**:
   - Download models into `<appDocs>/models/<file>.part` using `Dio` with `Range: bytes=<existing>-` headers for pause/resume.
   - Persist `prompter_model_meta.json` and auto-heal metadata if a GGUF file exists at `>= 99%` of expected size.
4. **`chat_engine.dart`**:
   - Use a single-flight `Future` mutex (`_synchronized`) so `loadModel`, `unloadModel`, and `generateStream` never race.
   - Buffer streaming tokens with an anti-prompt holdback window so stop sequences never leak to the UI.

---

### Step 6 — Offline Voice Mode (`lib/engine/services/voice_service.dart` + `chat_screen.dart`)
1. Initialize `SpeechToText` and `FlutterTts` (`en-US`, speech rate `0.5`, `awaitSpeakCompletion(true)`).
2. Listen with `onDevice: true` so speech recognition never leaves the phone.
3. In `ChatScreen`:
   - Add an AppBar toggle (**Speak replies offline**) and a mic button in the composer.
   - Buffer streamed LLM tokens until `.`, `!`, `?`, or `\n` and call `voice.speak(sentence)` so the assistant starts speaking before the full reply finishes.
   - Call `voice.stopSpeaking()` inside `_stopGeneration()` and `dispose()` for instant **barge-in** interruption.

---

### Step 7 — Offline Knowledge Base RAG (`document_service.dart` + `knowledge_service.dart` + `document_qa_screen.dart`)
1. **`DocumentService`**: Extract text from `.txt`/`.md` (`utf8.decode`), `.docx` (`ZipDecoder` + `XmlDocument`), and `.pdf` (`PdfDocument` + `PdfTextExtractor`). Split text into ~1,100-character chunks with 150-character overlap (`chunkText`).
2. **`KnowledgeService`**: Store document metadata and chunks in SQLite. On query, score every chunk using exact phrase bonus + tokenized BM25/term-frequency overlap (ignoring common English stop words) and return the top 4 `KnowledgeChunkMatch` results with `citationLabel` (`filename §chunk`).
3. **`DocumentQaScreen`**: Stream an `ANSWER:` / `KEY POINTS:` prompt into `ChatEngine` and display `StructuredResponseCard` with `Sources` citation chips.

---

### Step 8 — Offline Scan & Receipt OCR (`vision_engine.dart` + `image_qa_screen.dart`)
1. Pick or capture an image via `image_picker` (`maxWidth: 1600`, `imageQuality: 85`).
2. Run `TextRecognizer(script: TextRecognitionScript.latin).processImage(InputImage.fromFilePath(file.path))` inside a `try/finally` that always calls `recognizer.close()`.
3. Show the detected character count + 3 quick-action chips (*"Extract total, date, and merchant"*, *"List all items and prices"*, *"Summarize this text"*) and stream structured `SUMMARY:` / `DETAILS:` results into `StructuredResponseCard`.

---

### Step 9 — Proactive Local Assistant (`proactive_service.dart` + `proactive_screen.dart`)
1. Define a top-level `@pragma('vm:entry-point') void edgedWorkmanagerDispatcher()` for Workmanager background tasks.
2. In `ProactiveService`, initialize `FlutterLocalNotificationsPlugin`, save reminders in `ProactiveReminderEntity`, show instant/scheduled local notifications, and toggle the 24-hour periodic Workmanager briefing task.
3. In `ProactiveScreen`, gather recent chat titles, indexed Knowledge doc names, and pending reminders, ask `ChatEngine` for `OVERVIEW:` / `HIGHLIGHTS:` / `NEXT ACTIONS:`, and render with workspace stat pills + `StructuredResponseCard`.

---

### Step 10 — Navigation Shell, Providers & Device-Aware Model Selection
1. Wire all singletons (`AppDatabase`, `ModelManager`, `ChatEngine`, `VoiceService`, `VisionEngine`, `KnowledgeService`, `ProactiveService`) in `lib/providers/app_providers.dart`.
2. Build `MainShellScreen` with 5 tabs: `Chats`, `Knowledge`, `Scan`, `Skills`, `Settings` (showing an onboarding banner on `Knowledge` / `Scan` / `Skills` if no model is downloaded yet).
3. In `ModelSelectionScreen`, read `DeviceService.getCompatibilityReport()` (`effectiveRamGb = totalRamGb - 1.5`) and highlight the single **`⭐ Best for Device`** tier (`0.8B` < 3 GB usable, `2B` 3–5 GB usable, `4B` ≥ 5 GB usable).
4. In `ModelDownloadScreen`, place **Resume / Retry** above a sanitized error message inside `SingleChildScrollView`, and use `WidgetsBindingObserver` to auto-resume if Android drops the socket while backgrounded.

---

### Step 11 — Test, Build & Ship
1. Run static analysis and unit tests:
   ```powershell
   dart analyze --no-fatal-warnings
   flutter test --no-pub
   ```
2. Build the signed release APK & Play Store App Bundle (`.aab`):
   ```powershell
   .\android-pack.ps1 -AppBundle
   ```
3. Install onto a connected Android phone via USB debugging:
   ```powershell
   adb install -r "dist\Edged-v1.0.0-release.apk"
   ```
4. Upload `dist\Edged-v1.0.0-release.aab` and the assets in `dist\play_store_assets\` to Google Play Console (Closed testing with 12+ testers for 14 days → Production).
