# Test Strategy

## 1. Layered Verification Pyramid

1. **Host Unit & Domain Tests (`flutter test`):**
   - `MirageResponseParser`: real captured JSON outputs (`000000231049`, `000000000139`, `form`, `text`), missing/null sections, invalid geometry clamping.
   - `SceneUnderstandingEngine` & `ContextualQueryResolver`: entity deduplication, left/center/right positioning, grounded relations, temporal diff, offline follow-up QA.
   - `HazardIntelligenceEngine` & `IoUTracker`: all 5 hazard categories, 5 separate confidence fields, multi-frame track persistence, degraded quality handling.
   - `OpenetraSafetyPolicy` & `SafetySpeechGuard`: asserts prohibited safety/distance/counterfeit phrases are always rewritten/blocked.
   - `ScriptDetector`, `OcrRouter`, `ReadingOrderReconstructor`: Latin + all 7 Indic Unicode blocks, line sorting, missing-pack disclosure.
   - `AIModelOrchestrator` & `DeviceResourceManager`: task routing, operating modes, lazy load/unload, thermal safety disclosure.
   - `OpenetraDatabase` (`sqflite_common_ffi`) & `ModelChecksumVerifier`: real SQLite CRUD, foreign key cascades, full user wipe, SHA-256 mismatch failure.
   - `CurrencyRecognitionService` & `ObjectMemory`: multi-candidate disambiguation, uncertainty reporting, non-counterfeit disclaimer.

2. **Accessibility & UI Widget Tests (`flutter test`):**
   - Verifies semantic labels, button roles, `>= 64dp` touch targets, `liveRegion` output updates, and `VoiceIntentRouter` multi-language matching.

3. **Native Android ARM64 Integration & Emulator Verification:**
   - Build `app-debug.apk` for `android-arm64` via NDK 27 + CMake 3.22.1 linking `libcactus.a`.
   - Execute real on-device/emulator native JNI verification loading `mirage.cact`, verifying SHA-256, and running `cactus_describe` on `stop_sign_231049.jpg` and `living_room_139.jpg` inside `Medium_Phone_API_35` (`arm64-v8a`), inspecting `adb logcat` for exact timings, outputs, and crash-free completion.
