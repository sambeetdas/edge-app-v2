# Product Requirements Document (PRD) — Edged (Flutter)

## 1. Product Vision
**Edged** (`com.edgedai.app`) puts a capable AI assistant **entirely on the user's Android or iOS phone**. After a one-time GGUF model download, every feature works **100% offline and privately** — prompts, documents, photos, and chat history never leave the device.

## 2. Target Users
| Segment | Core Need |
|---|---|
| Privacy-conscious users | Zero cloud telemetry; prompts and files stay on-device. |
| Low / expensive connectivity users | Full offline operation after one-time model download. |
| Students & knowledge workers | Summarize, translate, explain code, and query PDFs/DOCX/notes. |
| AI enthusiasts & tinkerers | Choose Lite/Standard/Pro GGUF tiers and author custom skills & games. |
| Casual users | Play conversational AI games offline. |

## 3. Scope & Feature Pillars
1. **Onboarding & Local Authentication**: Phone number + 25-country autocomplete picker and local 6-digit OTP gate with 30-day persistent session (`flutter_secure_storage`).
2. **Model Tier Management**: 7 curated GGUF model tiers (Lite, Standard, Pro) with device RAM/storage compatibility checks, resumable downloads, wakelock protection, and orphaned-file metadata self-healing.
3. **Capability-Gated Navigation**: Bottom navigation dynamically unlocks `Chats`, `Skills`, `Image` (vision tiers only), `Docs` (`maxContextTokens >= 2048` only), and `Games` once a model is downloaded.
4. **Offline AI Chat**: Multi-session SQLite-persisted conversations with token-by-token streaming, 10s "Still thinking…" indicator, 120s timeout, auto-titling, and live device context awareness.
5. **Agent Skills**: 6 built-in single-shot productivity skills + user-created custom skills persisted in SQLite.
6. **Document Q&A**: Local text extraction for `.txt`, `.md`, `.docx`, and `.pdf` (≤ 10 MB) with token budgeting and truncation warnings.
7. **Image Q&A**: Camera capture and gallery selection for vision-capable tiers.
8. **AI Games**: 9 built-in conversational games (including strict word-chain validation) + custom game builder.
9. **Settings & Attribution**: Active model storage management, model switching/deletion, sign-out, and "Built by Sambeet Das" attribution (`Edged v1.0.0`).

## 4. Model Tiers Catalogue
| Tier | Model | Approx. Size | Min RAM | Vision | Docs Q&A | Format |
|---|---|---:|---:|:---:|:---:|---|
| Lite | SmolVLM2 500M | ~0.6 GB | 4 GB | Yes | No (1k ctx) | ChatML |
| Standard | **Qwen2.5-VL 3B** (Recommended) | ~3.3 GB | 6 GB | Yes | Yes | ChatML |
| Standard | Gemma 3 4B IT | ~3.3 GB | 6 GB | Yes | Yes | Gemma |
| Standard | Qwen3 4B | ~2.7 GB | 6 GB | No | Yes | ChatML (`/no_think`) |
| Pro | Phi-4 Multimodal | ~3.2 GB | 8 GB | Yes | Yes | Phi3 |
| Pro | Qwen3 14B | ~9.7 GB | 12 GB | No | Yes | ChatML (`/no_think`) |
| Pro | Phi-4 14B | ~9.1 GB | 12 GB | No | Yes | Phi3 |

## 5. Known Product Limitations / Future Milestones
- **Native GGUF Runtime**: `ChatEngine` bridges to `MethodChannel('com.edgedai.app/llama')` and uses an offline deterministic preview fallback when the native `llama.cpp` AAR/XCFramework is not yet bundled.
- **Multimodal Vision Embeddings**: `VisionEngine` currently passes image metadata + prompt to `ChatEngine`; native MTMD (`mmproj`) tensor embedding is a future native-layer milestone.
- **Verification**: Flutter SDK is not installed on the current build host, so `flutter pub get`, `flutter test`, and device builds remain pending.
