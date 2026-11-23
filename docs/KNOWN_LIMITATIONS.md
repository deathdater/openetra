# Known Limitations & Honest Gaps

1. **Physical Distance & Velocity:** Mirage does not provide calibrated metric depth or true object velocity. Until a validated `DepthProvider` pack is integrated and calibrated, Openetra reports image-relative zones (`foreground`, `left`, `center`, `right`, `overhead`) and box-expansion looming cues only.
2. **Mirage Language & OCR Limits:** Mirage `language` supports 7 European languages (`en, de, fr, es, it, nl, pl`) and Latin OCR only. Indic speech and text depend on dedicated Indic OCR/ASR/TTS packs.
3. **Indic OCR & ASR Pack Provisioning (Phase 5):** Phase 0–4 delivers the verified `OcrRouter`, `ScriptDetector`, `AsrProvider`, and `TtsProvider` contracts plus Android offline TTS verification; downloadable PP-OCRv5/Tesseract and `sherpa-onnx` IndicConformer binary packs require Phase 5 bundling/benchmarking.
4. **Kannada OCR Ambiguity:** PaddleOCR lacks a PP-OCRv5 Kannada model (`ka_PP-OCRv3_mobile_rec` only); `tesseract-ocr/tessdata_fast` (`kan.traineddata`, 3.44 MB) is selected for Phase 5 benchmarking.
5. **Indian Currency Classifier (Phase 6):** Requires training and benchmarking a labelled ₹10–₹500 dataset (MobileNetV3 INT8 TFLite) across folds/lighting; Phase 4 delivers the interface + Mirage OCR numeral cross-check + mandatory uncertainty/non-counterfeit guards.
6. **Hardware Verification Scope:** Host verification ran on Apple Silicon CPU and Phase 6 APK verification targets the Android ARM64 emulator (`Medium_Phone_API_35`); physical entry/mid/flagship Android device power and thermal profiling remains Phase 7 work.
7. **Safety Scope:** Openetra is a visual aid and **never** a substitute for a white cane, guide dog, or O&M training.
