# Openetra Context Changelog

## [0.5.0-phase4] - 2026-11-23
### Added
- Implemented `HazardTaxonomy`, `IoUTracker`, and `HazardIntelligenceEngine` with 5-factor confidence separation and cooldown deduplication.
- Implemented `SafetySpeechGuard` and `OpenetraSafetyPolicy` blocking unsafe crossing, clear-path, uncalibrated distance, and counterfeit claims.
- Implemented `ScriptDetector`, `ReadingOrderReconstructor`, and `OcrRouter` wired end-to-end across Workflows A–E.

## [0.4.0-phase3] - 2026-11-23
### Added
- Implemented `SceneUnderstandingEngine` with entity deduplication, deterministic relative zones, relation confidence filtering, temporal scene diff, and accessibility speech composition.
- Implemented `ContextualQueryResolver` for offline follow-up questions with freshness validation and zero pixel retention.

## [0.3.0-phase2] - 2026-11-23
### Added
- Installed `ndk;27.0.12077973` & `cmake;3.22.1` and vendored verified Cactus `4.1.4` static libraries + `mirage.cact`.
- Built C++ JNI bridge (`openetra_mirage_jni.cpp` + `CMakeLists.txt`) and Kotlin plugins (`MirageEnginePlugin`, `CameraXCaptureManager`, `DeviceResourcePlugin`, `HapticsPlugin`).
- Implemented Dart `MirageResponseParser` and `MirageInferenceProvider` wired into `OpenetraDependencies.bootstrap`.

## [0.2.0-phase1] - 2026-11-23
### Added
- Scaffolded Flutter Android application (`com.openetra.app`) with Gradle `8.7`, AGP `8.5.2`, Kotlin `1.9.24`, and Dart `3.4.4`-pinned dependencies.
- Implemented all 18 core domain entities, typed errors, 10-table offline `OpenetraDatabase`, and streaming SHA-256 `ModelChecksumVerifier`.
- Implemented `AIModelRegistry`, serialized `AIModelOrchestrator`, `DeviceResourceManager`, `SpeechController`, `VoiceIntentRouter` (EN/HI/KN), `AccessibilityAnnouncer`, `OpenetraCoordinator`, all 11 BLoC modules, and WCAG AAA accessible screens.

## [0.1.0-phase0] - 2026-11-23
### Added
- Initialized Git repository on `main` and created `.gitignore`.
- Created local versioned context tracking under `.openetra_context/`.
- Completed Phase 0 repository reconnaissance, toolchain verification, Cactus 4.1.4 + Mirage C ABI empirical verification on Apple Silicon host, and Indic/specialist model evaluation.
- Authored complete Phase 0 mandatory architecture, AI registry, safety, Indic strategy, accessibility, database, and evaluation documentation suite under `docs/`.
