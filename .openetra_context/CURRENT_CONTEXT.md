# Openetra Local Engineering Context

**Current Version:** `0.5.0-phase4`  
**Phase:** Phase 4 — Independent Hazard Intelligence, Safety Policy Guard & Workflows B–E  
**Last Updated:** 2026-11-23  
**Git Branch:** `main`  

## Implemented Components (`v0.5.0-phase4`)
- **Independent Hazard Intelligence (`lib/features/hazard_detection/domain/`):**
  - `HazardTaxonomy`: covers all 5 required hazard categories (ground-level, vertical overhead, elevation change, traffic, indoor obstruction) plus fire/smoke/broken-glass/warning text.
  - `IoUTracker`: pure-Dart multi-frame IoU tracker providing persistent `trackId`, consecutive hit tracking, temporal persistence score, and bbox growth looming indicator.
  - `HazardIntelligenceEngine`: image quality gate -> candidate extraction -> IoU tracking -> corridor check -> 5 separate confidence values (`distanceConfidence` strictly `null` without calibrated depth) -> severity & alert cooldown.
- **Safety Policy Gate (`lib/core/safety/`):**
  - `SafetySpeechGuard` & `OpenetraSafetyPolicy`: filters every `AssistantResponse`, blocking/rewriting `"safe to cross"`, `"obstacle-free"`, `"path is clear"`, uncalibrated meter/feet claims, counterfeit claims, and cane replacement phrasing; logs sanitization events to SQLite.
- **Workflow C Smart Reader (`lib/features/smart_reader/domain/`):**
  - `ScriptDetector` (Latin + Devanagari, Kannada, Tamil, Telugu, Malayalam, Bengali, Mixed), `ReadingOrderReconstructor`, and `OcrRouter` (Mirage Latin OCR + pluggable Indic provider + missing-pack notice).
- Workflows A–E wired end-to-end inside `OpenetraDependencies.bootstrap` and `OpenetraCoordinator`.

## Next Milestone (`v0.6.0-mvp-vertical-slice`)
Implement comprehensive unit, BLoC, SQLite, safety, OCR, currency/object-memory, and accessibility widget tests; build `android-arm64` APK; run real Mirage ARM64 JNI verification on `Medium_Phone_API_35` emulator; publish measured Android ARM64 benchmarks.
