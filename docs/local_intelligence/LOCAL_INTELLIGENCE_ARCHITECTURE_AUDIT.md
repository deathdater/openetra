# Openetra Local Intelligence (Beta) — Architecture & Repository Audit (Stage A)

**Audit Date:** 2026-11-23  
**Repository Baseline Commit:** `caf96c4` (`main`, 77/77 host tests passing, `flutter analyze`: 0 issues, arm64 APK `149.8 MB`)  
**Flutter / Dart:** Flutter `3.22.3` (stable) / Dart `3.4.4`  
**Android Toolchain:** `compileSdk 36`, `targetSdk 35`, `minSdk 26`, NDK `27.0.12077973`, Java 17, ABIs `arm64-v8a` & `armeabi-v7a`

---

## 1. Existing Repository Architecture & Reusable Components

| Responsibility | Existing Openetra Component | Reuse Decision for Local Intelligence |
|---|---|---|
| State management | `flutter_bloc ^8.1.6` (15 BLoCs) | **Reuse** — add a single self-contained `LocalIntelligenceBloc` (zero new state frameworks). |
| Local persistence | `OpenetraDatabase` (`lib/core/storage/openetra_database.dart`, SQLite v4) | **Extend** to SQLite **v5** adding `operation_history_events` and `local_intelligence_models`; store feature toggles & retention in existing `assistive_preferences`. |
| Operation execution | `OpenetraCoordinator` + `TaskOrchestrator` (`lib/core/assistive/task_orchestrator.dart`) | **Observe passively** — publish non-blocking (`unawaited`) sanitized `OperationHistoryEvent` records after existing workflows finish/fail/cancel. Never block or intercept. |
| Speech & audio | `AudioArbitrator` + `SpeechController` (FIFO queue) + `DialLocalizer` / `OpenetraLocalizer` | **Reuse** — speak summaries & history entries via existing speech pipeline; never create a second TTS service. |
| Haptics | `HapticFeedbackManager` + `HapticsPlugin.kt` | **Reuse** existing haptic vocabulary. |
| Theme & accessible UI | `OpenetraTheme` (`OpenetraPalette` Dark/Light), `AccessibleActionTile`, `openetra_components.dart` | **Reuse** all design tokens & accessible components (`>=64dp` targets, `OpenetraSectionHeader`, `OpenetraCard`, `OpenetraEmptyState`, `showOpenetraConfirmDialog`). |
| Model integrity | `ModelChecksumVerifier` (SHA-256) | **Reuse** for verifying downloaded/imported `.litertlm` packages before activation. |
| Privacy wipe | `OpenetraDatabase.deleteAllUserData()` + `SettingsBloc` | **Extend** so full data wipe clears `operation_history_events`, while keeping Local Intelligence's independent **Clear History**, **Delete Model**, and **Reset Local Intelligence** actions clearly separated. |
| Native Android ML | LiteRT (`com.google.ai.edge.litert:litert:1.4.2`), Cactus C++ (Mirage), Kotlin plugins in `MainActivity.kt` | **Add** optional Kotlin plugin `LocalIntelligencePlugin` (`com.openetra.app/local_intelligence`) bridging device capability probing, checksum-verified `.litertlm` storage, and LiteRT-LM (`com.google.ai.edge.litertlm:litertlm-android`) inference. |

---

## 2. Privacy & Manifest Boundary Assessment

- **Current Manifest (`android/app/src/main/AndroidManifest.xml`):** Intentionally omits `INTERNET` so core Openetra is 100% offline.
- **Boundary for Local Intelligence Beta:**
  - All core Openetra capabilities (Mirage, OCR, ASR, TTS, object memory, scene memory, hazard cues, gestures, flashlight, emergency) remain **100% offline** with zero network calls.
  - Local Intelligence is **disabled by default** (`enabled = false`, `historyEnabled = false`, `summariesEnabled = false`).
  - No model is bundled in `assets/` (preventing APK bloat) and no model is ever auto-downloaded.
  - Model downloads require explicit user consent, display exact package size & licence, respect a **Wi-Fi-only** preference, verify SHA-256 checksums, and never transmit history or telemetry. Local `.litertlm` file sideload/import is also supported for air-gapped devices.

---

## 3. Runtime & Candidate Model Compatibility Review

| Model ID | Name | Licence | Format / Quant | Approx. Size | Min Device Profile | Notes |
|---|---|---|---|---|---|---|
| `qwen3-0.6b-q4` | Qwen3-0.6B | Apache 2.0 | `.litertlm` INT4 | ~450 MB | `arm64-v8a`, Android 8+, >= 3 GB RAM | Primary recommended compact model; multilingual incl. English & Indic scripts. |
| `qwen3-1.7b-q4` | Qwen3-1.7B | Apache 2.0 | `.litertlm` INT4 | ~1.0 GB | `arm64-v8a`, Android 8+, >= 4 GB RAM | Higher-quality summarization on mid-range/flagship phones. |
| `gemma-3n-e2b-it-q4` | Gemma 3n E2B-IT | Gemma Terms of Use | `.litertlm` INT4 | ~2.1 GB | `arm64-v8a`, Android 10+, >= 6 GB RAM | Marked incompatible on <6 GB RAM or 32-bit devices; requires explicit licence acknowledgement. |

**Important Honesty Rule:** Where a device does not meet RAM/ABI/storage requirements, or when no `.litertlm` model is installed/verified, Local Intelligence transparently falls back to **Deterministic Structured Summaries** derived directly from SQLite `operation_history_events` — never fabricating AI output.

---

## 4. Regression Risk Register

| Risk ID | Risk | Severity | Mitigation |
|---|---|---|---|
| LI-R1 | History logging slows down or throws inside Scene/OCR/Object/Emergency workflows | Critical | Passive `unawaited` collector wrapped in `try/catch` with bounded in-memory deduplication; zero awaits on critical path. |
| LI-R2 | Large LLM causes OOM or starves Mirage VLM | Critical | Lazy loading, single active model, explicit `unload()` when disabled/backgrounded/under memory pressure, hard block on inference during active camera or emergency workflows. |
| LI-R3 | Sensitive data (raw images, full OCR docs, passwords, phone numbers) leaks into history | High | Strict `OperationHistorySanitizer` allowing only short redacted summaries (<=220 chars) and non-sensitive structured metadata; never stores raw frames, audio, or full OCR text. |
| LI-R4 | Historical summary sounds like a live camera observation | High | Every history detail & summary explicitly includes timestamp/date range and the disclaimer *"This is an earlier recorded activity, not a current camera view."* |
| LI-R5 | SQLite v4 -> v5 migration breaks existing user data | High | Additive `CREATE TABLE IF NOT EXISTS` migration tested via explicit `v4 -> v5` automated migration test. |
| LI-R6 | Existing 77 tests or arm64 APK build regress | High | Run `flutter analyze` + full `flutter test` after every implementation stage. |
