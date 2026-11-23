# OCR Engine Specification & Script Routing

## 1. Script Routing Architecture

```text
Captured Document Frame
         |
         v
Image Quality Gate (blur, exposure, framing)
         |
         v
Mirage / Region Text Detection + Script Classification
         |
         +-- Latin (U+0020..U+024F) ---------> Mirage Built-in OCR (Active Phase 2)
         |
         +-- Devanagari (U+0900..U+097F) ----> IndicOcrProvider (PP-OCRv5 devanagari / ML Kit / Tesseract hin/mar)
         +-- Kannada (U+0C80..U+0CFF) -------> IndicOcrProvider (Tesseract kan.traineddata / vetted ka model)
         +-- Tamil (U+0B80..U+0BFF) ---------> IndicOcrProvider (PP-OCRv5 ta / Tesseract tam)
         +-- Telugu (U+0C00..U+0C7F) --------> IndicOcrProvider (PP-OCRv5 te / Tesseract tel)
         +-- Malayalam (U+0D00..U+0D7F) -----> IndicOcrProvider (Tesseract mal)
         +-- Bengali (U+0980..U+09FF) -------> IndicOcrProvider (Tesseract ben)
         |
         v
ReadingOrderReconstructor (line clustering + top-to-bottom, left-to-right sort)
         |
         v
TextRecognitionResult (confidence + pack availability status) -> Offline TTS
```

---

## 2. ScriptDetector Rules
- Inspects Unicode blocks across extracted text spans or user-selected reading language (`hi-IN`/`mr-IN` -> Devanagari, `kn-IN` -> Kannada, `ta-IN` -> Tamil, `te-IN` -> Telugu, `ml-IN` -> Malayalam, `bn-IN` -> Bengali, `en-IN` -> Latin).
- Mixed scripts (`mixed`) split cleanly without dropping non-Latin lines.

## 3. Reading Order Reconstruction
- Lines with vertical overlap ratio `>= 0.5` (matching row height) are grouped into the same visual row and ordered left-to-right (`x1` ascending).
- Distinct visual rows are ordered top-to-bottom (`y1` ascending).
- Low-confidence spans (`< 0.40`) are flagged with uncertainty rather than silently presented as verified text.

## 4. Graceful Degradation for Unprovisioned Indic Packs
If a user in Reading mode requests Tamil, Telugu, Malayalam, or Bengali document reading before its optional offline `tessdata` pack is installed under app-private storage, `OcrRouter` honestly announces that that Indic script pack is not yet installed locally and avoids falling back blindly to Mirage's Latin-only OCR.

---

## 5. Verified Offline Android 15 ARM64 Implementation & Emulator Measurements (`IndicOcrPlugin`)
- **Channel & Native Providers:** `IndicOcrPlugin` (`com.openetra.app/indic_ocr`) wired to `NativeIndicOcrProvider` on the Dart side.
- **Bundled Hindi/Devanagari Route:** `com.google.mlkit:text-recognition-devanagari:16.0.1` (`libmlkit_google_ocr_pipeline.so`) executes primary Devanagari OCR; if `fullText` is empty, `NativeIndicOcrProvider` automatically falls back to `cz.adaptech.tesseract4android:tesseract4android:4.9.0` with SHA-256-verified bundled `hin.traineddata` (`4c73ffc59d497c186b19d1e90f5d721d678ea6b2e277b719bee4e2af12271825`).
- **Bundled Kannada Route:** Tesseract `4.9.0` with SHA-256-verified bundled `kan.traineddata` (`bd31e6b6ae93271e3bcf5383d306d8eefbb91542937cd6d735a5930c970e61d8`).
- **Additional Optional Languages:** `tam`, `tel`, `mal`, `ben` `.traineddata` packs supported on disk in `filesDir/tesseract/tessdata/` when provisioned via Model Manager.
- **Emulator Results (`Medium_Phone_API_35`, `800x220` high-contrast rendered bitmaps):**
  - ML Kit Devanagari (`नमस्ते निकास 500`): `208 ms`, exact text recovered.
  - Tesseract `hin` (`नमस्ते निकास 500`): `27 ms`, exact text recovered.
  - Tesseract `kan` (`ಬೆಂಗಳೂರು 500`): `14 ms`, exact text recovered.
