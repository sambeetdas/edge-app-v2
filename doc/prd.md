# Product Requirements Document (PRD) — Edged (Flutter)

## 1. Product Vision
**Edged** (`com.edgedai.app`) puts a capable AI assistant **entirely on the user's Android or iOS phone**. After a one-time GGUF model download, every feature works **100% offline and privately** — prompts, voice, documents, receipts/photos, reminders, and chat history never leave the device.

## 2. Target Users
| Segment | Core Need |
|---|---|
| Privacy-conscious users | Zero cloud telemetry; prompts, voice, and files stay on-device. |
| Low / expensive connectivity users | Full offline operation after one-time model download. |
| Students & knowledge workers | Query personal PDFs/DOCX/MD/TXT with inline citations, summarize, translate, and explain code. |
| Mobile productivity users | Scan receipts/images with offline OCR, speak hands-free with barge-in, and receive local daily briefings & reminders. |
| AI enthusiasts & power users | Choose Lite/Standard/Pro GGUF tiers matched to device RAM/storage and author custom skills. |

## 3. Scope & Feature Pillars
1. **Device-Native Authentication & Optional Profile**: Uses the phone's built-in biometric or device PIN (`local_auth`, enabled by default when a screen lock is configured) with no custom login wall, plus optional local-only Name, Phone, and Email fields in Settings (`flutter_secure_storage`).
2. **Device-Aware Model Tier Management**: 7 curated GGUF model tiers (Lite, Standard, Pro) with **Best for Device** RAM/storage recommendation, resumable `.part` downloads (`Dio`), foreground auto-resume, `WakelockPlus` protection, and orphaned-file metadata self-healing.
3. **5-Tab Navigation + Proactive Route**: Bottom navigation displays `Chats`, `Knowledge`, `Scan`, `Agents`, and `Settings`, with `/proactive` (`ProactiveScreen`) accessible from the Chats AppBar.
4. **Offline AI Chat + Voice Mode**: Multi-session SQLite-persisted conversations with `llama_flutter_android` token streaming, 10s "Still thinking…" indicator, 120s timeout, auto-titling, live device context awareness, on-device English Speech-to-Text (`speech_to_text`), sentence-buffered Text-to-Speech (`flutter_tts`), and real-time barge-in stop.
5. **Offline Knowledge Base (RAG + Citations)**: Multi-document `.txt`, `.md`, `.docx`, and `.pdf` indexing (≤ 10 MB) stored in SQLite (`KnowledgeDocumentEntity`, `KnowledgeChunkEntity`) with chunking, hybrid keyword/BM25 retrieval, structured `StructuredResponseCard` answers, and inline `[filename §chunk]` source citations.
6. **Offline Scan & Receipt OCR**: Camera capture and Android Photo Picker (`image_picker`) using on-device ML Kit Latin OCR (`google_mlkit_text_recognition`) feeding into `ChatEngine` with quick-action chips and structured `SUMMARY` / `DETAILS` output.
7. **Proactive Local Assistant (`/proactive`)**: On-device Daily Briefing (`OVERVIEW`, `HIGHLIGHTS`, `NEXT ACTIONS`), local scheduled reminders (`ProactiveReminderEntity`), and 24-hour background briefings (`workmanager` + `flutter_local_notifications`).
8. **Unified Agents & A2A Chaining**: 12 predefined Agents (Scheduled Email, Scheduled WhatsApp, Knowledge RAG, OCR & Receipt, Action & Reminder, Daily Briefing, plus all 6 classic productivity skills), custom SQLite Agents (`CustomAgentEntity`), and sequential Agent-to-Agent (A2A) handoffs.
9. **Settings & Attribution**: Active model storage management, model switching/deletion, theme switching, App Lock toggle & Lock App button, optional local Profile, and "Built by Sambeet Das" attribution (`Edged v1.0.0`).

## 4. Model Tiers Catalogue
| Tier | Model | Approx. Size | Min RAM | Scan OCR | Knowledge RAG | Format |
|---|---|---:|---:|:---:|:---:|---|
| Lite | Qwen3.5 0.8B | ~0.5 GB | 4 GB | Yes | No (1k ctx) | ChatML (`/no_think`) |
| Standard | **Qwen3.5 2B** | ~1.2 GB | 4 GB | Yes | Yes (4k ctx) | ChatML (`/no_think`) |
| Standard | Phi-4-mini Instruct | ~2.3 GB | 6 GB | Yes | Yes (8k ctx) | Phi3 |
| Standard | Gemma 3n E2B IT | ~2.8 GB | 6 GB | Yes | Yes (4k ctx) | Gemma |
| Standard | Qwen3.5 4B | ~2.8 GB | 6 GB | Yes | Yes (8k ctx) | ChatML (`/no_think`) |
| Pro | Gemma 3n E4B IT | ~4.2 GB | 8 GB | Yes | Yes (8k ctx) | Gemma |
| Pro | Qwen3.5 9B | ~5.3 GB | 10 GB | Yes | Yes (8k ctx) | ChatML (`/no_think`) |

## 5. Technical Architecture & Verified Status
- **Native GGUF Runtime**: `ChatEngine` uses `llama_flutter_android` (`llama.cpp`) on Android and an offline deterministic preview streamer on platforms without a linked native backend.
- **On-Device OCR**: `VisionEngine` uses `google_mlkit_text_recognition` (`TextRecognitionScript.latin`) for offline text extraction before querying `ChatEngine`.
- **Verification**: `dart analyze --no-fatal-warnings` (0 errors), `flutter test --no-pub` (12/12 unit tests passing), signed release `.apk` / `.aab` (`1.0.0+4`) built via `android-pack.ps1`, and verified on physical Android hardware (`ZD222XK2FC`).
