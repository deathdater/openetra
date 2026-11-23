# Openetra Local Engineering Context

**Current Version:** `1.0.0-release-candidate`  
**Phase:** Release Candidate (`v1.0.0-release-candidate`) — All-8-Language Offline Indian OCR, Live LiteRT XNNPACK Verification, Coordinator & UI Hardening, Zero-Network R8 Release APK  
**Last Updated:** 2026-11-23  
**Git Branch:** `main`  

## Verified Build, Security & Runtime Baseline (`v1.0.0-release-candidate`)
- **Host Analysis & Test Suite:** `flutter analyze` (`No issues found!`); `flutter test -r expanded` (`40/40` passing test cases across all baseline suites + `v1_release_readiness_test.dart`).
- **Production Release APK (`app-release.apk`, `142,993,414 B`, `pubspec` `1.0.0+2`):**
  - Built with R8 minification & resource shrinking (`minifyEnabled = true`, `shrinkResources = true`, `proguard-rules.pro`) and `src/release/AndroidManifest.xml` stripping `INTERNET` and `ACCESS_NETWORK_STATE` via `tools:node="remove"`.
  - `aapt2 dump permissions` verified zero `INTERNET` and zero `ACCESS_NETWORK_STATE` (only `CAMERA`, `RECORD_AUDIO`, `VIBRATE`, `DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`).
  - Cold-launched `com.openetra.app/.MainActivity` on `Medium_Phone_API_35` in `2560 ms`; PID `8429` verified running after 3s with zero Openetra/Flutter/R8/JNI fatal exceptions.
- **Android 15 ARM64 Instrumentation (`Medium_Phone_API_35`, `arm64-v8a`):**
  - `MirageNativeInstrumentedTest` (`1.305 s`): `cactus_load` `107.16 ms`, COCO `231049` `363.73 ms` / `230.52 ms`, COCO `139` `303.86 ms`.
  - `IndicAndSpecialistInstrumentedTest` (`1.75 s`): ML Kit Devanagari (`520 ms`, `"नमस्ते निकास 500"`), Tesseract `hin` (`32 ms`), `mar` (`16 ms`), `kan` (`17 ms`), `tam` (`14 ms`), `tel` (`18 ms`), `mal` (`10 ms`), `ben` (`11 ms`) — all 7 recovered exact Unicode text — `sherpa-onnx` Silero VAD (`19 ms`, `detected=true`, `segments=1`), ML Kit Barcode `17.3.0` (`53 ms`, `"8901058851234"`), Mirage 3-choice `form` (`107.71 ms`, `stop=0.7898`), `computeCropDescriptor96` (`21.03 ms`, norm `1.0000`, selfCos `1.0000`, diffCos `0.8886`), and live LiteRT `1.4.2` XNNPACK `Interpreter` (`1.02 ms`, 192 float32 elements, `1.5 -> 4.5`).

## Pending Beyond Emulator Verification
- Train/bundle `.tflite` Indian banknote classifier weights and evaluate optional monocular depth `.tflite` weights for active `SpecialistVisionPlugin` LiteRT `1.4.2` slots.
- Provision downloadable `IndicConformer` (`sherpa-onnx`) ASR weights via Model Manager / local storage.
- Execute physical Android phone (entry/mid/flagship) battery/thermal benchmarks and blind-user usability trials.
