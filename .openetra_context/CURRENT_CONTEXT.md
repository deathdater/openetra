# Openetra Local Engineering Context

**Current Version:** `0.7.0-phase5-indic-intelligence`  
**Phase:** Phase 5 — Offline Indic OCR, Silero VAD / sherpa-onnx ASR & Direct EN/HI/KN Localisation  
**Last Updated:** 2026-11-23  
**Git Branch:** `main`  

## Verified Phase 5 Assets & Plugins
- `android/app/libs/sherpa-onnx-static-link-onnxruntime-2.0.3.aar` (`38 MB`, Apache-2.0, SHA-256 `7744a3a8...`)
- `assets/models/vad/silero_vad.int8.onnx` (`208 KB`, MIT, SHA-256 `c36d490a...`)
- `assets/models/tessdata/hin.traineddata` (`1.07 MB`, Apache-2.0, SHA-256 `4c73ffc5...`)
- `assets/models/tessdata/kan.traineddata` (`3.44 MB`, Apache-2.0, SHA-256 `bd31e6b6...`)
- Google ML Kit Devanagari OCR (`16.0.1`), Tesseract4Android (`4.9.0`), Google ML Kit Barcode (`17.3.0`), Google AI Edge LiteRT (`2.4.0`).
- **Native Plugins:** `IndicOcrPlugin` (`com.openetra.app/indic_ocr`) and `OfflineSpeechPlugin` (`com.openetra.app/speech`) registered in `MainActivity.kt`.
- **Dart Layer:** `OpenetraLocalizer` (authoring native EN/HI/KN strings across Scene, Hazard, SafetySpeechGuard, Currency), `NativeIndicOcrProvider`, `NativeOfflineAsrProvider`, and gated offline microphone trigger on `HomeScreen`.

## Next Milestone (`v0.8.0-phase6-specialist-and-shopping`)
Implement SQLite schema v2 (`local_products` + seeded Indian EAN-890 catalog), `SpecialistVisionPlugin` (ML Kit Barcode, 96-dim visual crop descriptor, LiteRT `2.4.0` currency slot), cosine-similarity matching in `ObjectMemoryBloc`, Mirage `form` + OCR + LiteRT fusion in `CurrencyRecognitionService`, and `ShoppingScreen`.
