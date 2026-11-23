# Openetra Architecture Decision Records (ADRs)

## ADR-001: Integrate Cactus 4.1.4 Static Library via Native C++ JNI Instead of Dart FFI
- **Status:** Accepted
- **Context:** Cactus Compute publishes `android-arm64/libcactus.a` and `android-armv7/libcactus.a` (static archives linked against NDK LLVM `libc++`), rather than prebuilt Android `.so` files.
- **Decision:** Build a thin C++ JNI shared library (`libopenetra_mirage.so`) via Android NDK 27 + CMake 3.22.1 that statically links `libcactus.a`, exposes mutex-guarded JNI calls, and bridges to Dart via a dedicated single-thread Kotlin `MethodChannel` worker (`MirageEnginePlugin`).
- **Consequences:** Zero UI-thread blocking, native Bitmap/YUV-to-RGB memory handling without Dart heap copies, full compatibility with Android 15 16-KB page alignment (`-Wl,-z,max-page-size=16384`).

## ADR-002: Enforce Selective Mirage Sections & Fields Per Operating Mode
- **Status:** Accepted
- **Context:** Host benchmarks show Mirage latency grows substantially when generating dense polygon/bitmap masks (`372.0 ms` polygons vs `156.9 ms` no-mask on host CPU). Moreover, passing `"attributes"` inside `fields` throws error `-1`.
- **Decision:** Use explicit `MirageQueryProfile` presets:
  - `sceneSummary`: `sections: ["scene", "objects", "relations", "events"]`, `fields: ["bbox", "score", "position", "description"]` (no masks).
  - `hazardScan`: `sections: ["objects", "regions"]`, `fields: ["bbox", "score", "position", "description"]` (with `mask_format: "largest"` only when contour geometry is needed).
  - `latinOcr`: `sections: ["text"]`.
  - `structuredForm`: `form` schema extraction (`53.7 ms` host CPU).
- **Consequences:** Lower RAM churn, lower battery drain, and strictly validated option payloads.

## ADR-003: Exclude Meta MMS VITS TTS (`CC-BY-NC`) from Production Assets
- **Status:** Accepted
- **Context:** `sherpa-onnx` packages Meta MMS voices (`vits-mms-hin/kan/tam/tel`) under `CC-BY-NC 4.0`, prohibiting commercial distribution or product-wide deployment without restriction.
- **Decision:** Do not bundle `CC-BY-NC` weights. Primary offline TTS verifies locally installed Android offline `TextToSpeech` voices (`!isNetworkConnectionRequired && !KEY_FEATURE_NOT_INSTALLED`) and supports pluggable MIT/Apache-2.0 Piper or AI4Bharat ONNX voice packs.

## ADR-004: Hybrid Indic OCR Strategy (PaddleOCR PP-OCRv5 + Tesseract `tessdata_fast`)
- **Status:** Accepted
- **Context:** Verification of PaddleOCR `main` showed PP-OCRv5 mobile recognisers exist for `en`, `devanagari` (Hindi/Marathi), `ta` (Tamil), and `te` (Telugu), while Kannada (`ka_dict.txt`) only has a legacy `PP-OCRv3` model with noisy dictionary header lines (`k a _ i m g / 1 2`) and lacks PP-OCRv5 coverage for Kannada, Bengali, and Malayalam. Meanwhile `tesseract-ocr/tessdata_fast` (Apache-2.0) provides 0.82–5.03 MB integer LSTM weights for all 8 target languages.
- **Decision:** Route Latin OCR to Mirage first; build a clean script-aware `OcrRouter` supporting PP-OCRv5 (`devanagari`, `ta`, `te`) and `tesseract-ocr/tessdata_fast` (`kan`, `ben`, `mal`, fallback `hin`/`mar`) via independently provisioned offline packs.

## ADR-005: Reject AGPL-3.0 Object Detectors and Keep Hazard Safety Independent
- **Status:** Accepted
- **Context:** Ultralytics YOLOv8/YOLO11 weights carry AGPL-3.0 licences. Furthermore, Mirage's raw detection scores are not calibrated probabilities of physical danger.
- **Decision:** Prohibit AGPL-3.0 models. Keep Mirage as primary general detector; evaluate Apache-2.0 `YOLOX-Nano` / `EfficientDet-Lite0` only if benchmarks justify an auxiliary hazard detector. Always compute hazard alerts in an independent `HazardIntelligenceEngine` + `SafetySpeechGuard`.

## ADR-006: Omit `INTERNET` Permission in Production Android Manifest
- **Status:** Accepted
- **Context:** P0 offline and privacy mandates require guaranteeing zero unintended network calls.
- **Decision:** Declare only `CAMERA`, `RECORD_AUDIO`, and `VIBRATE` in `android/app/src/main/AndroidManifest.xml` (Flutter debug manifest retains debug VM socket only in debug builds). All user records live in local SQLite with user-triggered deletion.
