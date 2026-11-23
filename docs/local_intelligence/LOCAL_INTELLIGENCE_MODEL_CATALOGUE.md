# Openetra Local Intelligence (Beta) — Verified Model Catalogue

**Source of Truth:** `lib/features/local_intelligence/domain/local_model_catalogue.dart`

| Model ID | Display Name | Quantisation | Approx. Size | Min RAM | Min Android API | ABI | Licence |
|---|---|---|---|---|---|---|---|
| `qwen3-0.6b-q4` | Qwen3-0.6B (Compact) | INT4 (`.litertlm`) | ~450 MB | 3.0 GB | API 26 (Android 8) | `arm64-v8a` | Apache 2.0 |
| `qwen3-1.7b-q4` | Qwen3-1.7B (Balanced) | INT4 (`.litertlm`) | ~1.0 GB | 4.0 GB | API 26 (Android 8) | `arm64-v8a` | Apache 2.0 |
| `gemma-3n-e2b-it-q4` | Gemma 3n E2B-IT (High-RAM) | INT4 (`.litertlm`) | ~2.15 GB | 6.0 GB | API 29 (Android 10) | `arm64-v8a` | Gemma Terms of Use (explicit acceptance) |

## Verification & Fallback Guarantee
- Models are **never** bundled in the APK (`assets/`).
- Activation requires: device hardware compatibility pass -> `.litertlm` extension & SHA-256 checksum verification -> runtime initialization -> smoke test pass.
- Whenever no model is installed, incompatible, unloaded, or fails inference, `SummaryOrchestrator` deterministically falls back to `DeterministicSummaryEngine`.
