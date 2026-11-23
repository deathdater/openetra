# Openetra Local Engineering Context

**Current Version:** `0.3.0-phase2`  
**Phase:** Phase 2 — Native Android Mirage Integration (Cactus 4.1.4 + C++ JNI + CameraX + DeviceResource + Haptics)  
**Last Updated:** 2026-11-23  
**Git Branch:** `main`  

## Verified Toolchain & Native Assets
- **Android NDK / CMake:** `ndk/27.0.12077973` & `cmake/3.22.1` installed and verified.
- **Vendored Native Runtime (`android/app/src/main/cpp/third_party/cactus/`):** `cactus.h`, `arm64-v8a/libcactus.a`, `armeabi-v7a/libcactus.a`, `LICENSE`, `manifest.json` (Cactus `4.1.4`, SHA-256 verified).
- **Bundled Model & Test Fixtures:** `assets/models/mirage.cact` (`21,611,043 B`, SHA-256 `4249a0f7...`), `assets/test_fixtures/stop_sign_231049.jpg`, `assets/test_fixtures/living_room_139.jpg`, and captured probes under `test/fixtures/mirage/`.

## Implemented Components (`v0.3.0-phase2`)
- **C++ JNI Bridge (`openetra_mirage_jni.cpp` + `CMakeLists.txt`):** Mutex-locked `cactus_load` & `cactus_describe`, reusable 16 MB buffer, `jbyteArray` UTF-8 JSON return, native Laplacian/luma quality evaluation, 16 KB page alignment (`-Wl,-z,max-page-size=16384`).
- **Kotlin Plugins (`com.openetra.app`):** `MirageNativeBridge`, `MirageEnginePlugin` (single-thread `ExecutorService` + asset SHA-256 provisioning + EXIF-aware bitmap decoding), `CameraXCaptureManager` (`YUV_420_888` -> RGB24 + pitch), `DeviceResourcePlugin` (battery/thermal/RAM/offline `TextToSpeech.getVoices()`), `HapticsPlugin`, wired in `MainActivity`.
- **Dart Mirage Layer:** `MirageResponseParser` & `MirageInferenceProvider` wired into `OpenetraDependencies.bootstrap`.

## Next Milestone (`v0.4.0-phase3`)
Implement `SceneUnderstandingEngine` (entity deduplication, relative positioning, grounded relationships, temporal diff) and `ContextualQueryResolver` (rolling `SceneGraph` window & offline follow-up QA).
