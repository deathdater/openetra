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
| `cactus-mirage-2bit` | Scene, open-vocab objects, bbox, masks, Latin OCR | Cactus `4.1.4` (`libcactus.a`) | `21.6 MB` (~95 MB RAM) | Apache-2.0 | **91** | **Phase 2 (Active MVP)** |
| `ppocrv5-devanagari-mobile` | Hindi/Marathi line OCR | ONNX Runtime / MNN | `~8–14 MB` | Apache-2.0 | **88** | Phase 5 Pack |
| `ppocrv5-ta-mobile` / `te-mobile` | Tamil / Telugu line OCR | ONNX Runtime / MNN | `~8–14 MB` each | Apache-2.0 | **87** | Phase 5 Pack |
| `tesseract-fast-kan` (+ `ben/mal`) | Kannada, Bengali, Malayalam OCR | Tesseract LSTM (JNI) | `0.82–5.03 MB` (`kan` `3.44 MB`) | Apache-2.0 | **82** | Phase 5 Pack |
| `mlkit-text-devanagari` | Alternative Devanagari OCR | ML Kit v2 | `~4 MB` bundled | Google ML Kit ToS | **75** | Optional Fallback (lacks Dravidian) |
| `indicconformer-sherpa-int8` | Indian ASR (hi/kn/ta/te/ml/mr/bn) | `sherpa-onnx` | `~180–190 MB` per pack | MIT / Apache-2.0 | **86** | Phase 5 Pack |
| `silero-vad-v4` | Offline VAD (speech boundary) | `sherpa-onnx` | `~1.8 MB` | MIT | **93** | Phase 5 Pack |
| `android-offline-tts` | System offline voices (`getVoices`) | Android `TextToSpeech` | `0 MB` app footprint | System OS | **89** | **Phase 1–2 (Active MVP)** |
| `piper-vits-hi-mit` | Neural offline Hindi TTS | `sherpa-onnx` | `~18–65 MB` | MIT / CC-BY | **84** | Phase 5 Pack |
| `vits-mms-*` (Meta) | Indic TTS | `sherpa-onnx` | `~35 MB` | **CC-BY-NC 4.0** | **Rejected** | Excluded (non-commercial) |
| `currency-mobilenetv3-int8` | ₹10/20/50/100/200/500 | LiteRT / TFLite | `~2.5–4 MB` | Apache-2.0 | **89** | Phase 6 Pack (interface live Phase 4) |
| `depth-anything-v2-small-int8` | Monocular relative depth | TFLite / ORT | `~25 MB` | Apache-2.0 | **83** | Phase 6–7 Optional |
| `midas-v21-small-int8` | Lightweight depth baseline | TFLite | `~21 MB` | MIT | **76** | Benchmark baseline |
| `yolox-nano` / `efficientdet-lite0` | Auxiliary hazard detector | TFLite / ORT | `~2.2–4.4 MB` | Apache-2.0 | **81** | Deferred unless Mirage recall insufficient |
| `yolov8n` / `yolo11n` | Object detection | — | `~3–6 MB` | **AGPL-3.0** | **Rejected** | Excluded (AGPL-3.0) |
| `mobilenetv3-embed` / `dinov2-s-int8` | Personal object re-ID | TFLite / ORT | `~3 MB` / `~22 MB` | Apache-2.0 | **84** | Phase 6 Pack |
| `mlkit-barcode-bundled` / `zxing` | 1D/2D product barcode | ML Kit / ZXing | `~2.2 MB` / `~0.5 MB` | ML Kit / Apache-2.0 | **90** | Phase 6 Shopping |

---

## 3. Dependency & Compatibility Matrix

| Package / Component | Pinned Version | Runtime / ABI | Dart / Android Constraint | Licence |
|---|---|---|---|---|
| `Cactus Runtime` | `4.1.4` (`f4ab2741`) | `arm64-v8a`, `armeabi-v7a` (`libcactus.a`) | NDK 27, CMake 3.22.1, `minSdk 26`, 16 KB page alignment | Apache-2.0 |
| `Mirage Weights` | `76c1e9e5` (`mirage.cact`) | Cactus Vision (`bitmask & 4`) | `21.61 MB`, bundled or app-private storage | Apache-2.0 |
| `flutter_bloc` + `equatable` | `^8.1.6` + `^2.0.5` | Dart `>=3.4.0 <4.0.0` | Compatible with Flutter `3.22.3` / Dart `3.4.4` | MIT |
| `sqflite` + `sqflite_common_ffi` | `^2.3.3+1` + `^2.3.3` | Android SQLite + host FFI tests | Compatible with Dart `3.4.4` | MIT |
| `flutter_tts` | `^4.0.2` | Android `TextToSpeech` | Paired with native `getVoices()` offline filter | MIT |
| `Android CameraX` | `1.3.4` (`core`, `camera2`, `lifecycle`) | Android API 26–35 | AGP `8.5.2`, Gradle `8.7`, JDK `17`/`21` | Apache-2.0 |
| `sherpa_onnx` (Phase 5) | `^1.10+` / `^2.0.2` | `arm64-v8a`, `armeabi-v7a` | Check Dart `3.4` vs SDK constraint before Phase 5 bump | Apache-2.0 |
