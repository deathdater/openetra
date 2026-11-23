# AI Model Registry, Compatibility Matrix & Weighted Selection

## 1. Selection Criteria Weights (Section 20)
- **Accuracy & Task Suitability:** 35%
- **Latency:** 20%
- **Memory Footprint:** 15%
- **Energy Consumption:** 15%
- **Android Compatibility:** 10%
- **Licensing & Maintainability:** 5%  
*(Safety-critical hazard tasks override general score with false-negative risk priority.)*

---

## 2. Core & Candidate Model Registry

| Model ID | Task | Runtime | Size / RAM | Licence | Weighted Score (0–100) | Phase / Status |
|---|---|---|---|---|---:|---|
| `cactus-mirage-2bit` | Scene, open-vocab objects, bbox, masks, Latin OCR, constrained `form` | Cactus `4.1.4` (`libcactus.a`) | `21.6 MB` (`4249a0f7...`) | Apache-2.0 | **91** | **Phase 2 & 6 Active** (Android 15 emulator verified) |
| `mlkit-text-devanagari` | Hindi / Devanagari primary OCR | Google ML Kit v2 (`16.0.1`) | Bundled `libmlkit_google_ocr_pipeline.so` | Google ML Kit ToS | **88** | **Phase 5 Active** (emulator verified: `208 ms`) |
| `tesseract-fast-hin` | Hindi / Marathi Devanagari fallback OCR | `tesseract4android` `4.9.0` | `1.12 MB` (`4c73ffc5...`) | Apache-2.0 | **85** | **Phase 5 Active** (emulator verified: `27 ms`) |
| `tesseract-fast-kan` (+ `tam/tel/mal/ben`) | Kannada (bundled); Tamil/Telugu/Malayalam/Bengali optional packs | `tesseract4android` `4.9.0` | `3.61 MB` (`bd31e6b6...`) | Apache-2.0 | **84** | **Phase 5 Active** (`kan` emulator verified: `14 ms`) |
| `ppocrv5-devanagari/ta/te-mobile` | Alternate Indic OCR packs | ONNX Runtime | `~8–14 MB` each | Apache-2.0 | **87** | Evaluated Phase 0 / optional external upgrade |
| `silero-vad-int8` | Offline speech boundary (VAD) | `sherpa-onnx` `2.0.3` | `213 KB` (`c36d490a...`) | MIT | **93** | **Phase 5 Active** (emulator verified: `14 ms`) |
| `indicconformer-sherpa-int8` | Offline Indian ASR (hi/kn/ta/te/ml/mr/bn) | `sherpa-onnx` `2.0.3` (`OfflineNemoEncDecCtcModelConfig`) | `~180–190 MB` per pack | MIT / Apache-2.0 | **86** | **Phase 5 Runtime Active** (`loadAsrPack` SHA-256 gated; weights external) |
| `android-offline-tts` | System offline voices (`getVoices`) | Android `TextToSpeech` | `0 MB` app footprint | System OS | **89** | **Phase 1–2 Active** (`DeviceResourcePlugin` checked) |
| `piper-vits-hi-mit` | Optional neural offline Hindi TTS | `sherpa-onnx` | `~18–65 MB` | Per-voice `MODEL_CARD` audit | **84** | Phase 7 Optional Pack |
| `vits-mms-*` (Meta) | Indic TTS | `sherpa-onnx` | `~35 MB` | **CC-BY-NC 4.0** | **Rejected** | Excluded (non-commercial) |
| `currency-mobilenetv3-int8` | ₹10/20/50/100/200/500 | LiteRT `1.4.2` (`org.tensorflow.lite.Interpreter`) + Mirage `form` + OCR | `libtensorflowlite_jni.so` slot | Apache-2.0 | **89** | **Phase 6 Fusion & Runtime Active** (`.tflite` weights pending dataset training) |
| `depth-anything-v2-small-int8` | Monocular relative depth | TFLite / ORT | `~25 MB` | Apache-2.0 | **83** | Phase 7 Optional |
| `midas-v21-small-int8` | Lightweight depth baseline | TFLite | `~21 MB` | MIT | **76** | Benchmark baseline |
| `yolox-nano` / `efficientdet-lite0` | Auxiliary hazard detector | TFLite / ORT | `~2.2–4.4 MB` | Apache-2.0 | **81** | Deferred unless Mirage recall insufficient |
| `yolov8n` / `yolo11n` | Object detection | — | `~3–6 MB` | **AGPL-3.0** | **Rejected** | Excluded (AGPL-3.0) |
| `openetra-hsv-edge-embed96` | Personal object re-identification descriptor | Native Kotlin (`SpecialistVisionPlugin`) | 96-float L2 vector (~384 B/crop) | Apache-2.0 | **85** | **Phase 6 Active** (emulator verified: `18.53 ms`) |
| `mlkit-barcode-bundled` | Offline 1D/2D product barcode scanning | Google ML Kit Barcode (`17.3.0`) | Bundled `libbarhopper_v3.so` | Google ML Kit ToS | **90** | **Phase 6 Active** (emulator verified Code-128: `42 ms`) |

---

## 3. Dependency & Compatibility Matrix

| Package / Component | Pinned Version | Runtime / ABI | Dart / Android Constraint | Licence |
|---|---|---|---|---|
| `Cactus Runtime` | `4.1.4` (`f4ab2741`) | `arm64-v8a`, `armeabi-v7a` (`libcactus.a`) | NDK 27, CMake 3.22.1, `minSdk 26`, 16 KB page alignment | Apache-2.0 |
| `Mirage Weights` | `76c1e9e5` (`mirage.cact`) | Cactus Vision (`bitmask & 4`) | `21,611,043 B`, SHA-256 `4249a0f7...` | Apache-2.0 |
| `sherpa-onnx` AAR | `2.0.3` static-link OR (`7744a3a8...`) | `arm64-v8a`, `armeabi-v7a` (`libsherpa-onnx-jni.so`) | Bundled in `android/app/libs/` with `silero_vad.int8.onnx` (`c36d490a...`) | Apache-2.0 / MIT |
| `tesseract4android` | `4.9.0` | `arm64-v8a`, `armeabi-v7a` (`libtesseract.so`) | Bundled `hin` (`4c73ffc5...`) & `kan` (`bd31e6b6...`) `tessdata_fast` | Apache-2.0 |
| `ML Kit Devanagari / Barcode` | `16.0.1` / `17.3.0` | `arm64-v8a`, `armeabi-v7a` | Bundled offline pipelines (`libmlkit_google_ocr_pipeline.so`, `libbarhopper_v3.so`) | Google ML Kit ToS |
| `Google AI Edge LiteRT` | `1.4.2` | `arm64-v8a`, `armeabi-v7a` (`libtensorflowlite_jni.so`) | 16 KB aligned; compatible with AGP `8.5.2` + Kotlin `2.2.20` | Apache-2.0 |
| `flutter_bloc` + `equatable` | `^8.1.6` + `^2.0.5` | Dart `>=3.4.0 <4.0.0` | Compatible with Flutter `3.22.3` / Dart `3.4.4` | MIT |
| `sqflite` + `sqflite_common_ffi` | `^2.3.3+1` + `^2.3.3` | Android SQLite (`schemaVersion = 2`) + host FFI | Offline 11-table DB (`v1 -> v2` + `local_products`) | MIT |
| `flutter_tts` | `^4.0.2` | Android `TextToSpeech` | Paired with native `getVoices()` offline filter | MIT |
| `Android CameraX` | `1.3.4` (`core`, `camera2`, `lifecycle`) | Android API 26–35 (`compileSdk 36`, `targetSdk 35`) | AGP `8.5.2`, Kotlin `2.2.20`, Gradle `8.7`, JDK `21` | Apache-2.0 |
