# Openetra Context Changelog

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
