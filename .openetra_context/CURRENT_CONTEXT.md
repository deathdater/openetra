# Openetra Local Engineering Context

**Current Version:** `0.6.0-mvp-vertical-slice`  
**Phase:** Verified Vertical Slice (Phases 0–4 Live on Android ARM64 + Phase 5–6 Extensible Interfaces)  
**Last Updated:** 2026-11-23  
**Git Branch:** `main`  

## Verified Build & Test Baseline
- **`flutter analyze`:** `No issues found!`
- **Host Test Suite (`flutter test`):** `24/24` passing (Mirage response parser on real COCO fixtures, Scene Understanding deduplication & offline QA, Hazard 5-category & IoUTracker, `SafetySpeechGuard` sanitization, Indic script detection & reading order, `AIModelOrchestrator` & thermal throttling, 10-table SQLite via `sqflite_common_ffi` & SHA-256 verification, Currency & Object Memory workflows, TalkBack semantics & `>=64dp` tap targets, EN/HI/KN `VoiceIntentRouter`).
- **Android ARM64 APK Build:** `build/app/outputs/flutter-apk/app-debug.apk` (Gradle `8.7`, AGP `8.5.2`, Kotlin `2.2.20`, `compileSdk 36`, `minSdk 26`, NDK `27.0.12077973`, CMake `3.22.1`, contains `libopenetra_mirage.so` + `libc++_shared.so` + `mirage.cact`; production `AndroidManifest.xml` omits `INTERNET`).
- **Android ARM64 Emulator JNI Verification (`Medium_Phone_API_35`, Android 15 `arm64-v8a`):**
  - `MirageNativeInstrumentedTest`: Passed (`1/1`, `4.11 s`), verified SHA-256 (`4249a0f7...`), `cactus_load` `57.09 ms`, `stop_sign_231049.jpg` `961.40 ms` / `1431.23 ms` (`stop sign`, `ARRET`), `living_room_139.jpg` `1429.90 ms` (`living room`, `chair`).
  - `MainActivity` cold launch: `Status: ok`, `TotalTime: 5425 ms`, Dart VM initialized cleanly with zero uncaught errors.

## Active Next Work (Phase 5+)
1. Package & benchmark offline Indic OCR packs (`ppocrv5-devanagari/ta/te` + `tesseract-fast-kan/ben/mal`) and `sherpa-onnx` IndicConformer + Silero VAD packs.
2. Train & quantise Indian currency MobileNetV3 INT8 TFLite model (`₹10..₹500`) and evaluate Depth Anything V2 Small INT8.
3. Execute battery/thermal profiling and blind-user usability trials on physical Android devices (Phase 7–8).
