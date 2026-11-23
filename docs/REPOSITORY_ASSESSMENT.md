# Openetra Repository Assessment & Reconnaissance

**Date:** 2026-11-23  
**Milestone:** `v0.1.0-phase0`  
**Workspace:** `/Volumes/Dater 5TB/1.0 Python Projects/Openetra`

---

## 1. Existing Repository State
Inspection of the workspace at project kickoff established that `/Volumes/Dater 5TB/1.0 Python Projects/Openetra` was an empty greenfield directory with no existing Git history, Flutter code, Android Gradle configuration, native C/C++ files, database schema, or bundled model assets.

Consequently, there is no legacy functionality to regress or preserve, and Openetra is being architected cleanly from Phase 0 following Clean Architecture + BLoC and a strict four-layer intelligence separation.

---

## 2. Installed Toolchain & Environment Audit

| Component | Detected State | Version / Path | Assessment |
|---|---|---|---|
| Host OS | macOS Apple Silicon | macOS 15.1 (`arm64`) | Suitable for Flutter/Android builds and ARM64 emulation |
| Flutter SDK | Installed | `3.22.3` (`stable`, `/Users/deathdater/development/flutter/bin/flutter`) | Ready; requires sandbox bypass in agent terminal |
| Dart SDK | Installed (via Flutter) | `3.4.4` | **Constraint:** Pub dependencies must support Dart `>=3.4.0 <4.0.0` |
| Java Runtime | Android Studio JBR | OpenJDK `21.0.10` (`/Applications/Android Studio.app/Contents/jbr/Contents/Home`) | **Conflict risk:** Flutter 3.22 defaults to Gradle 7.6.x, which fails on Java 21 |
| Android SDK | Installed | `/Users/deathdater/Library/Android/sdk` (`android-31`, `34`, `35`, `36`, build-tools `37.0.0`) | Ready; targets API 35 cleanly |
| Android NDK | **Missing** | None installed | **Gap:** Must install `ndk;27.0.12077973` via `sdkmanager` in Phase 2 |
| CMake | **Missing** | None installed | **Gap:** Must install `cmake;3.22.1` via `sdkmanager` in Phase 2 |
| Android Emulator | Installed + AVDs | Emulator `36.5.11`, system-image `android-35;google_apis_playstore;arm64-v8a`, AVDs `Medium_Phone_API_35`, `Pixel_Fold_API_35` | Ready for real ARM64 JNI/APK verification |
| C/C++ Host Compiler | Apple Clang | `16.0.0` (`arm64-apple-darwin24.1.0`) | Verified compiling native C harnesses against Cactus `4.1.4` |
| Python | Installed | `3.10.x` (`/Library/Frameworks/Python.framework/Versions/3.10/bin/python3`) | Available for host verification scripts only; **never embedded in Android APK** |

---

## 3. Existing Architecture, Reusable Implementations & Missing Functionality
- **Existing Architecture:** None (greenfield).
- **Reusable External Artifacts Verified in Phase 0:**
  - Official Cactus Runtime `4.1.4` static Android libraries (`libcactus.a` for `android-arm64`, `android-armv7`, `android-riscv64`) and `cactus.h` from `Cactus-Compute/cactus` (Apache-2.0).
  - Official Mirage 2-bit quantised model `mirage.cact` (`21,611,043 B`) from `Cactus-Compute/mirage` (Apache-2.0).
  - Host-side C verification harness (`mirage_probe.c`) successfully exercised `cactus_load` and `cactus_describe` across 5 COCO reference images.
- **Missing Functionality (Full Implementation Roadmap):**
  - Clean Architecture Flutter scaffold, domain entities, and 11 BLoC state managers.
  - Voice-first, TalkBack-ready UI with WCAG AAA contrast and haptic/audio feedback.
  - Native Android C++ JNI wrapper around `libcactus.a` and CameraX `YUV_420_888` pipeline.
  - `SceneUnderstandingEngine`, `HazardIntelligenceEngine`, `OpenetraSafetyPolicy`, and offline SQLite storage.
  - Pluggable Indic OCR/ASR/TTS and specialist currency/depth providers.

---

## 4. Architectural Gaps & Dependency Conflicts Identified

1. **Java 21 vs. Flutter 3.22 Default Gradle Wrapper:**
   - `flutter create` in Flutter 3.22.3 generates `gradle-7.6.3` and AGP `7.3.0`, which throw `Unsupported class file major version 65` on OpenJDK 21.
   - **Mitigation:** Immediately upgrade Gradle wrapper to `8.7`, AGP to `8.5.2`, Kotlin to `1.9.24`, and compile options to Java 17 bytecode.
2. **Dart `3.4.4` Package Compatibility:**
   - Newer package major versions (e.g., `flutter_bloc: ^9.x`, `camera: ^0.11.1+`) may require Dart `>=3.5.0` or `>=3.6.0`.
   - **Mitigation:** Pin tested versions compatible with Dart `3.4.4` (`flutter_bloc: ^8.1.6`, `sqflite: ^2.3.3+1`, `flutter_tts: ^4.0.2`).
3. **NDK C++ Standard Library Linkage for `libcactus.a`:**
   - Symbol inspection (`nm -u android-arm64/libcactus.a`) proved that Cactus links Android NDK LLVM `libc++` (`std::__ndk1::basic_string`, `std::__ndk1::locale`, `pthread_create`, `mmap`, `log`, `expf`).
   - **Mitigation:** Compile our JNI shared library (`libopenetra_mirage.so`) with `ANDROID_STL=c++_shared` (or `c++_static`), link `log`, `android`, `m`, `dl`, and enable 16 KB page alignment (`-Wl,-z,max-page-size=16384`) for Android 15+ compliance.
4. **Cactus C ABI Return Code Trap & Non-Thread-Safety:**
   - Probing revealed that `cactus_describe()` returns the **decoder token count** (e.g., `282`, `336`, `4`) rather than the JSON byte length, while writing a NUL-terminated UTF-8 JSON string into `out`. Truncating `out` to the return integer would corrupt the JSON.
   - Global state inside `libcactus.a` requires single-thread serialization via both a C++ `std::mutex` and a dedicated single-thread Kotlin `ExecutorService`.

---

## 5. Model Integration Risks & Mitigations

| Risk | Severity | Details | Mitigation |
|---|---|---|---|
| **Mirage `fields` validation** | High | Passing `"attributes"` causes `cactus_describe()` to fail with `-1: invalid options: fields has an unknown name attributes`. | Restrict `fields` strictly to `["bbox", "score", "mask", "position", "description"]`. |
| **Hallucinated scene relations** | High | COCO living room probe produced relation `{"subject": 8, "predicate": "on", "object": 7}` ("rug on dining table"). | Preserve observation confidence/source; validate spatial plausibility and never state speculative relations as fact. |
| **Mirage Latin-only OCR** | High | Mirage CTC reader supports 306 Latin/ASCII/Extended-A characters only; zero Indic script coverage. | Route Devanagari, Tamil, Telugu, Kannada, Malayalam, Bengali through dedicated Indic OCR providers. |
| **PaddleOCR Kannada gap** | Medium | `ka_dict.txt` maps to Kannada (`ka`), not Georgian, but only `ka_PP-OCRv3_mobile_rec` exists (not PP-OCRv5) and contains noisy header tokens. | Benchmark `ka_PP-OCRv3_mobile_rec` against Tesseract `kan.traineddata` (`tessdata_fast`, 3.44 MB) before shipping Kannada OCR. |
| **Meta MMS TTS licence** | Critical | `vits-mms-*` weights are licensed `CC-BY-NC 4.0` (non-commercial), restricting broad product distribution. | Exclude MMS weights from production bundles; use verified offline Android voices + MIT/Apache-2.0 Piper/AI4Bharat voices. |
| **YOLOv8/YOLO11 licence** | High | Ultralytics YOLO models carry AGPL-3.0 copyleft licences. | Reject AGPL models; evaluate Apache-2.0 `YOLOX-Nano` or `EfficientDet-Lite0` instead. |

---

## 6. Performance & Accessibility Considerations
- Running full Mirage sections with polygons/bitmaps on every camera frame would drain battery and cause thermal throttling. Use selective `sections`/`fields`, `STRATEGY_KEEP_ONLY_LATEST` CameraX backpressure, and adaptive mode cadence (`Eco` vs `HazardAwareness`).
- All audio output must enforce a microphone-gating state (`isAssistantSpeaking`) and support barge-in interruption so TalkBack or assistant speech never loops back into offline ASR.
- Android `AndroidManifest.xml` must omit `android.permission.INTERNET` in production release builds to enforce offline privacy at the OS boundary.

---

## 7. Recommended Immediate Changes (Execution Roadmap)
1. **Milestone `v0.1.0` (Phase 0):** Establish Git, local versioned context (`.openetra_context/`), and full `docs/` specification.
2. **Milestone `v0.2.0` (Phase 1):** Scaffold Flutter + Clean Architecture + 11 BLoCs + SQLite + TalkBack/voice-first shell using Gradle 8.7 / AGP 8.5.2.
3. **Milestone `v0.3.0` (Phase 2):** Install NDK 27 + CMake 3.22.1, build `libopenetra_mirage.so` over `libcactus.a`, wire CameraX + DeviceResource + Haptics plugins, and integrate `MirageInferenceProvider`.
4. **Milestone `v0.4.0` (Phase 3):** Build `SceneUnderstandingEngine` & `ContextualQueryResolver` (Workflow A).
5. **Milestone `v0.5.0` (Phase 4):** Build `HazardIntelligenceEngine`, `IoUTracker`, `OpenetraSafetyPolicy` / `SafetySpeechGuard`, and Workflows B–E.
6. **Milestone `v0.6.0`:** Run comprehensive unit/BLoC/widget/SQLite tests, build `android-arm64` APK, and execute live Mirage native inference verification on the `Medium_Phone_API_35` ARM64 emulator.
