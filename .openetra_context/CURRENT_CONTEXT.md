# Openetra Local Engineering Context

**Current Version:** `0.2.0-phase1`  
**Phase:** Phase 1 — Flutter Clean Architecture, 18 Core Data Contracts, Offline SQLite, AI Orchestration Core & Accessible Voice-First Shell  
**Last Updated:** 2026-11-23  
**Git Branch:** `main`  

## Active Toolchain & Verified Environment
- **Flutter / Dart:** `3.22.3` / `3.4.4` (all dependencies resolved cleanly via `flutter pub get`)
- **Android Build Setup:** Gradle `8.7`, AGP `8.5.2`, Kotlin `1.9.24`, `compileSdk = 35`, `minSdk = 26`, `targetSdk = 35`, `ndkVersion = "27.0.12077973"`, Java 17 bytecode target, production `AndroidManifest.xml` omits `INTERNET`.

## Implemented Components (`v0.2.0-phase1`)
- **Domain Entities (`lib/core/domain/entities/`):** All 18 standardized entities (`VisionObservation`, `SceneDescription`, `SceneGraph`, `ObjectDetection`, `ObjectAttribute`, `BoundingBox`, `SegmentationMask`, `SpatialRelationship`, `HazardObservation`, `HazardAssessment`, `TextRecognitionResult`, `SpeechRecognitionResult`, `AssistantResponse`, `ModelMetadata`, `ModelPerformance`, `DeviceResourceState`, `SafetyEvent`, plus `CurrencyRecognitionResult`, `PersonalObjectProfile`, `ImageQualityMetrics`).
- **Offline Storage (`lib/core/storage/`):** `OpenetraDatabase` (10 SQLite tables, FK cascades, atomic `deleteAllUserData()`), `ModelChecksumVerifier` (streaming SHA-256).
- **AI Core (`lib/core/inference/`, `lib/core/resource_management/`):** Replaceable provider interfaces, `AIModelRegistry` (pinned Mirage + Phase 5–6 packs), serialized `AIModelOrchestrator`, adaptive `DeviceResourceManager`.
- **Audio, Accessibility & BLoCs:** `SpeechController` (with mic-gating mutex and offline voice checks), `VoiceIntentRouter` (EN/HI/KN), `AccessibilityAnnouncer`, `HapticFeedbackService`, all 11 BLoCs, WCAG AAA high-contrast dark UI (`OnboardingScreen`, `HomeScreen`, `ObjectMemoryScreen`, `ModelManagerScreen`, `SettingsScreen`).

## Next Milestone (`v0.3.0-phase2`)
Install `ndk;27.0.12077973` & `cmake;3.22.1`, build `libopenetra_mirage.so` linking Cactus `4.1.4` `libcactus.a`, wire `CameraXCaptureManager`, `DeviceResourcePlugin`, `HapticsPlugin`, `MirageEnginePlugin`, and `MirageInferenceProvider` + `MirageResponseParser`.
