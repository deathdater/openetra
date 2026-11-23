# Openetra Context Changelog

## [1.0.0-release-candidate] - 2026-11-23
### Added & Verified
- Bundled & SHA-256-verified all 5 remaining Apache-2.0 `tesseract-ocr/tessdata_fast` models (`mar`, `tam`, `tel`, `mal`, `ben`) alongside `hin` & `kan`, covering all 8 target Indian languages (`en-IN` + 7 Indic scripts); updated `pubspec.yaml` (`1.0.0+2`), `IndicOcrPlugin.kt`, `NativeIndicOcrProvider` (`mr-IN -> mar`), and `AIModelRegistry`.
- Added uncalibrated LiteRT `1.4.2` relative depth slot (`loadDepthModel` / `estimateCenterDepthRgb` in `SpecialistVisionPlugin.kt` + `NativeDepthProvider`), `OpenetraCoordinator.stopAll()` and `registerPersonalObjectWithCamera`, 8-locale voice routing & doorway cue follow-ups, `HomeScreen` `Continuous Hazard Mode` toggle, `ObjectMemoryScreen` camera capture button, and two-step `SettingsScreen` wipe confirmation dialog.
- Configured `android/app/src/release/AndroidManifest.xml` (`tools:node="remove"` for `INTERNET` and `ACCESS_NETWORK_STATE`), `android/app/proguard-rules.pro`, and `minifyEnabled = true` / `shrinkResources = true` in `android/app/build.gradle`.
- Verified `app-release.apk` (`142,993,414 B`) declares zero network permissions (`aapt2 dump permissions`) and cold-launches on `Medium_Phone_API_35` in `2560 ms` (`PID 8429`, zero fatal errors); passed 40/40 host tests (`v1_release_readiness_test.dart`) and verified character-exact output across all 7 bundled Indic Tesseract packs plus live LiteRT `1.4.2` XNNPACK (`1.02 ms`, `litert_add_smoke.tflite`) on Android 15 ARM64 emulator.

## [0.9.0-phase5-7-verified] - 2026-11-23
### Added & Verified
- Pinned `com.google.ai.edge.litert:litert:1.4.2` (16 KB aligned, resolving `litert-api:2.4.0` Kotlin metadata `2.4.0` conflict against Kotlin `2.2.20` + AGP `8.5.2`).
- Guarded `FlutterLoader.getLookupKeyForAsset` lookups in `IndicOcrPlugin.kt` and `OfflineSpeechPlugin.kt` for standalone Android instrumentation tests.
- Authored 4 new host test suites (`openetra_localizer_test.dart`, `shopping_and_migration_test.dart`, `embeddings_and_currency_fusion_test.dart`, `native_indic_providers_test.dart`), bringing host tests to 36/36 passing.
- Authored `IndicAndSpecialistInstrumentedTest.kt` and verified live execution on `Medium_Phone_API_35` (`arm64-v8a`, Android 15): ML Kit Devanagari (`208 ms`), Tesseract `hin` (`27 ms`) & `kan` (`14 ms`), `sherpa-onnx` Silero VAD (`14 ms`), ML Kit Barcode `17.3.0` (`42 ms`), Mirage `form` (`120.65 ms`), and 96-dim crop embeddings (`18.53 ms`) alongside `MirageNativeInstrumentedTest` (`1.302 s`).
- Recorded observed Android 15 ARM64 emulator metrics across `docs/` and verified bundle `.so` / asset inventory without `INTERNET` in production `AndroidManifest.xml`.

## [0.8.0-phase6-specialist-and-shopping] - 2026-11-23
### Added
- Upgraded `OpenetraDatabase` to schema v2 (`local_products` table + `onUpgrade` migration + 5 seeded Indian EAN-890 sample items + `getObjectEmbeddings`, `lookupLocalProduct`, `upsertLocalProduct`, `listLocalProducts`).
- Implemented `SpecialistVisionPlugin` (`com.openetra.app/specialist`) with ML Kit `17.3.0` barcode decoding, 96-dim L2-normalized HSV+spatial+edge crop descriptor (`computeCropDescriptor96`), and LiteRT `2.4.0` currency slot, wired via `MainActivity.kt` and `native_specialist_providers.dart`.
- Integrated crop embedding matching into `ObjectMemoryBloc`, Mirage `form` + OCR + LiteRT fusion into `CurrencyRecognitionService`, and `SqliteProductCatalogLookup` + `ShoppingScreen` into `OpenetraCoordinator` and `HomeScreen`.

## [0.7.0-phase5-indic-intelligence] - 2026-11-23
### Added
- Vendored verified `sherpa-onnx 2.0.3` static-OR AAR, `silero_vad.int8.onnx`, `hin.traineddata`, and `kan.traineddata`; added ML Kit Devanagari, Tesseract4Android, ML Kit Barcode, and LiteRT Gradle dependencies.
- Implemented `IndicOcrPlugin` (`com.openetra.app/indic_ocr`) and `OfflineSpeechPlugin` (`com.openetra.app/speech`) plus Dart `NativeIndicOcrProvider` and `NativeOfflineAsrProvider`.
- Implemented `OpenetraLocalizer` authoring native EN/HI/KN safety, scene, hazard, and currency output without machine translation.

## [0.6.0-mvp-vertical-slice] - 2026-11-23
### Added & Verified
- Authored 24 passing host unit, BLoC, SQLite, safety, OCR, currency/object-memory, and accessibility widget tests plus `MirageNativeInstrumentedTest.kt`.
- Resolved `compileSdk 36` / Kotlin `2.2.20` compatibility and macOS ExFAT AppleDouble intermediate conflict via APFS buildDir redirection.
- Built `app-debug.apk` (`android-arm64`) bundling `libopenetra_mirage.so` + `mirage.cact` without `INTERNET` permission in production manifest.
- Executed live native Mirage JNI inference on `Medium_Phone_API_35` (`arm64-v8a`, Android 15), verified `MainActivity` cold launch, recorded real emulator timings in `docs/PERFORMANCE_BENCHMARKS.md`, and updated `docs/IMPLEMENTATION_STATUS.md`.

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
