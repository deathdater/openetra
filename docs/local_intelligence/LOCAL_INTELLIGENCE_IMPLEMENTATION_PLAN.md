# Openetra Local Intelligence (Beta) — Phased Implementation Plan

**Baseline Commit:** `caf96c4` (`77/77` tests passing, `0` analyze issues)

## Implementation Stages (Incremental & Regression-Gated)

### Stage B — Feature Boundary & Configuration Isolation
- Create `lib/features/local_intelligence/domain/local_intelligence_config.dart`:
  - `LocalIntelligenceConfig` (all disabled by default: `enabled = false`, `historyEnabled = false`, `summariesEnabled = false`, `wifiOnlyDownload = true`, `retentionDays = 30`, `activeModelId = null`).
  - `LocalIntelligenceAvailability` controller enforcing hard rules: disabled -> no inference; emergency/active camera -> inference deferred/blocked; missing/unverified model -> deterministic fallback.
- Persist config in existing `OpenetraDatabase.assistive_preferences` (no duplicate storage).

### Stage C — Local Operation History (No LLM Dependency)
- Upgrade `OpenetraDatabase` to `schemaVersion = 5` adding `operation_history_events` and `local_intelligence_models` with additive `v4 -> v5` migration.
- Create `lib/features/local_intelligence/domain/operation_history_event.dart`:
  - Versioned schema (`schemaVersion = 1`), validated `OperationType` (`sceneDescription`, `textReading`, `objectSearch`, `hazardScan`, `currencyCheck`, `sceneRecording`, `historicalSummary`), `OperationStatus` (`completed`, `notFound`, `cancelled`, `failed`), `OperationInitiator` (`user`, `system`), timestamps, duration, `OperationHistorySanitizer` (strips digits/passwords/excess length, never stores raw frames/audio/full OCR).
- Create non-blocking `OperationHistoryCollector` (bounded deduplication window, fire-and-forget `unawaited`, swallows DB failures cleanly) and wire passive observation hooks in `OpenetraCoordinator`.
- Build accessible `ActivityHistoryScreen` (date grouping, category/status filters, search, detail view with explicit *"earlier recorded activity, not a current view"* spoken readout, clear history).

### Stage D — Deterministic Summaries & Bounded Historical Q&A
- Create `DeterministicSummaryEngine` + `HistoryConversationContext` (session-scoped, bounded to last 6 turns, no unrestricted chatbot behavior):
  - 3 styles: **Brief**, **Detailed**, **Activity-focused**.
  - Structured validated `ActivitySummaryResult` (`title`, `dateRangeLabel`, `totalCount`, `completedCount`, `failedCount`, `categoryCounts`, `keyObservations`, `limitations`, `generatedByModelId`, `isDeterministicFallback`).
  - Answers scoped historical queries & follow-ups ("Summarise today", "How many were text-reading?", "What failed yesterday?", "Last 3 scene descriptions") strictly from actual SQLite records.

### Stage E & F — Verified Model Catalogue, Native LiteRT-LM Bridge & On-Device Inference
- Create `LocalModelManifest` (versioned catalogue for `Qwen3-0.6B`, `Qwen3-1.7B`, `Gemma 3n E2B-IT` with real licences, quantisation, sizes, RAM/ABI requirements).
- Create `LocalLlmEngine` interface + `NativeLocalIntelligenceBridge` (`com.openetra.app/local_intelligence` MethodChannel) + Kotlin `LocalIntelligencePlugin.kt` (real Android RAM/storage/ABI/Android-version compatibility probe, SHA-256 verification, model file lifecycle/deletion, and LiteRT-LM `.litertlm` runtime bridge with clean graceful fallback when runtime/model is absent).

### Stage G & H — AI Summarisation, Settings, Privacy, Retention & Failure Handling
- Create `SummaryOrchestrator` (retrieves bounded relevant records -> checks config & model -> runs local LLM if ready & verified -> validates structured output -> falls back to `DeterministicSummaryEngine` on any error/timeout/OOM).
- Create `LocalIntelligenceBloc` + `LocalIntelligenceSettingsScreen` (wired cleanly under `SettingsScreen` and Assistive Dial `More Tools` — disabled by default, independent toggles for Master Enable, Operation History, On-Device Summaries, Retention `7/30/90/Manual`, Model Catalogue & Delete Model, Clear History, and confirmed Reset Local Intelligence).

### Stage I — Full Verification, Regression Report & Release Documentation
- Add comprehensive unit, widget, migration (`v4 -> v5`), and end-to-end integration tests covering all 21 acceptance scenarios in Section 14.3.
- Run `flutter analyze`, full `flutter test -r expanded`, rebuild `arm64-v8a` release APK, and produce all Section 15 docs.
