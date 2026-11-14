# Software Architecture — Edged (Flutter)

## 1. Layered Module Overview

```
lib/
├── main.dart                     # ProviderScope + WidgetsFlutterBinding
├── app.dart                      # GoRouter routes + MaterialApp.router (Light/Dark Theme)
├── core/                         # Shared theme, colors, logo painter, formatters
├── engine/                       # Framework-agnostic AI engine (port of Prompter.AI.Edge)
│   ├── models/                   # ModelTier, PromptFormat, ChatModels
│   └── services/                 # ModelManager, ChatEngine, SkillsEngine, VisionEngine
├── data/                         # Persistence & platform data services
│   ├── database/                 # AppDatabase (sqflite -> edge_chat.db)
│   └── services/                 # AuthService, ChatHistoryService, CustomSkillsService,
│                                 # GamesService, DocumentService, DeviceService
├── providers/                    # Riverpod providers + shared model_loader_helper.dart
└── features/                     # Feature-sliced UI screens (Splash, Auth, Shell, Chat,
                                  # Skills, Image Q&A, Docs Q&A, Games, Settings/Models)
```

## 2. Engine Layer (`lib/engine/`)
- **`ModelTier`**: Single source of truth for all 7 GGUF tiers, HuggingFace URLs, byte sizes, RAM requirements, context limits, and `PromptFormat`.
- **`PromptFormat`**: Formats `ChatML` (`<|im_start|>/<|im_end|>`, optional `/no_think`), `Gemma` (`<start_of_turn>/<end_of_turn>`), and `Phi3` (`<|system|>/<|end|>`), and supplies per-family anti-prompts.
- **`ChatEngine`**: Uses a `Future` chain mutex (`_synchronized`) so only one load/unload/generation runs at a time. Streams tokens through an anti-prompt holdback buffer of length `maxAntiLen` so partial stop tokens are never emitted. Bridges to `MethodChannel('com.edgedai.app/llama')` + `EventChannel('com.edgedai.app/llama_tokens')` with an offline preview fallback when native `llama.cpp` is not linked.
- **`ModelManager`**: Streams downloads via `Dio` to `<appDocs>/models/`, supports `.part` HTTP Range resume, holds `WakelockPlus` during download, writes `prompter_model_meta.json`, and heals lost metadata by scanning for `>= 99%` sized GGUF files.

## 3. Data & Persistence (`lib/data/`)
- **SQLite (`edge_chat.db`)**:
  - `ChatSessionEntity` (`Id`, `Title`, `CreatedAt`, `UpdatedAt`, `Summary`, `SummarizedUpToMessageId`)
  - `ChatMessageEntity` (`Id`, `SessionId` indexed, `Role`, `Content`, `Timestamp`)
  - `CustomSkillEntity` (`Id`, `Name`, `Description`, `Icon`, `SystemPrompt`, `InputPlaceholder`, `Category`, `CreatedAt`)
  - `CustomGameEntity` (`Id`, `Name`, `Description`, `Icon`, `Category`, `SystemPrompt`, `StarterMessage`, `HowToPlay`, `CreatedAt`)
- **Secure Storage**: `AuthService` stores `auth_phone`, `auth_otp`, `auth_token`, `auth_expiry` in `FlutterSecureStorage`.
- **Native Device Channel (`com.edgedai.app/device`)**:
  - Android ([MainActivity.kt](file:///d:/Sambeet/Working%20Folder/edge,app,v2/android/app/src/main/kotlin/com/edgedai/app/MainActivity.kt)): `ActivityManager.MemoryInfo.totalMem` and `StatFs.availableBytes`.
  - iOS ([AppDelegate.swift](file:///d:/Sambeet/Working%20Folder/edge,app,v2/ios/Runner/AppDelegate.swift)): `ProcessInfo.processInfo.physicalMemory` and `volumeAvailableCapacityForImportantUsage`.

## 4. Navigation & State Flow
- **Startup**: `/loading` (`LoadingScreen`) checks `AuthService.isAuthenticated()` → routes to `/auth/phone` or `/home` (`MainShellScreen`).
- **Capability Gating**: `MainShellScreen` watches `downloadedModelProvider` and `activeModelTierProvider` to dynamically show/hide `Chats`, `Skills`, `Image`, `Docs`, and `Games` tabs alongside `Settings`.
- **Shared Model Loader**: `ensureModelLoadedFromWidget(ref)` in [model_loader_helper.dart](file:///d:/Sambeet/Working%20Folder/edge,app,v2/lib/providers/model_loader_helper.dart) centralizes model loading across Chat, Skills, Docs Q&A, Image Q&A, and Games.
