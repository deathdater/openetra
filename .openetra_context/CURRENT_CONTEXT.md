# Openetra Local Engineering Context

**Current Version:** `0.9.0-phase5-7-verified`  
**Phase:** Phase 5–6+7 Emulator Verification — Native Indic OCR/VAD, Barcode, Embeddings, Mirage `form`, LiteRT `1.4.2`, SQLite v2 Migration & Expanded Test Suite  
**Last Updated:** 2026-11-23  
**Git Branch:** `main`  

## Verified Build & Runtime Baseline (`v0.9.0-phase5-7-verified`)
- **Host Static Analysis & Test Suite:** `flutter analyze` (`No issues found!`); `flutter test -r expanded` (`36` passing test cases across all baseline + 4 Phase 5/6 suites: `openetra_localizer_test.dart`, `shopping_and_migration_test.dart`, `embeddings_and_currency_fusion_test.dart`, `native_indic_providers_test.dart`).
- **APK Packaging & Offline Manifest:** `flutter build apk --debug --target-platform android-arm64` bundles `libopenetra_mirage.so`, `libsherpa-onnx-jni.so`, `libtensorflowlite_jni.so` (LiteRT `1.4.2`), `libtesseract.so`, `libleptonica.so`, `libmlkit_google_ocr_pipeline.so`, `libbarhopper_v3.so`, `mirage.cact`, `hin.traineddata`, `kan.traineddata`, and `silero_vad.int8.onnx` across `arm64-v8a` & `armeabi-v7a`. Production `android/app/src/main/AndroidManifest.xml` omits `INTERNET`.
- **Android 15 `Medium_Phone_API_35` (`arm64-v8a`) Live Instrumentation Verification:**
  - `MirageNativeInstrumentedTest` (`1.302 s`): `cactus_load` `85.43 ms`, COCO `231049` `285.59 ms` / `291.42 ms`, COCO `139` `298.76 ms`.
  - `IndicAndSpecialistInstrumentedTest` (`0.822 s`): ML Kit Devanagari (`208 ms`, `"नमस्ते निकास 500"`), Tesseract `hin` (`27 ms`, `"नमस्ते निकास 500"`), Tesseract `kan` (`14 ms`, `"ಬೆಂಗಳೂರು 500"`), `sherpa-onnx 2.0.3` Silero VAD (`14 ms`, `detected=true`, `segments=1`), ML Kit Barcode `17.3.0` (`42 ms`, Code-128 `"8901058851234"`), Mirage 3-choice `form` (`120.65 ms`, `stop=0.7898`), `computeCropDescriptor96` (`18.53 ms`, L2 norm `1.0000`, selfCos `1.0000`, diffCos `0.8886`).

## Remaining Future Work (Post-`v0.9.0`)
- Train/bundle `.tflite` Indian banknote classifier weights for `SpecialistVisionPlugin` LiteRT `1.4.2` slot and evaluate optional monocular depth `.tflite`/ORT pack.
- Bundle or provision regional `IndicConformer` (`sherpa-onnx`) ASR weights and additional `tessdata` (`tam`/`tel`/`mal`/`ben`) packs via Model Manager.
- Execute physical Android phone (entry/mid/flagship) power/thermal benchmarks and accessibility trials with blind participants (Phase 7–8).
