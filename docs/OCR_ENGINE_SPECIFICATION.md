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
- **Channel & Native Providers:** `IndicOcrPlugin` (`com.openetra.app/indic_ocr`) wired to `NativeIndicOcrProvider` covering all 8 supported languages (`en`, `hi`, `mr`, `kn`, `ta`, `te`, `ml`, `bn`).
- **Bundled Devanagari Route (Hindi & Marathi):** `com.google.mlkit:text-recognition-devanagari:16.0.1` (`libmlkit_google_ocr_pipeline.so`) executes primary Devanagari OCR; if `fullText` is empty, `NativeIndicOcrProvider` automatically falls back to `cz.adaptech.tesseract4android:tesseract4android:4.9.0` using SHA-256-verified bundled `mar.traineddata` (`mr-IN`) or `hin.traineddata` (`hi-IN`).
- **Bundled Dravidian & Eastern Indic Routes:** Tesseract `4.9.0` with SHA-256-verified bundled `kan.traineddata`, `tam.traineddata`, `tel.traineddata`, `mal.traineddata`, and `ben.traineddata` provisioned in `filesDir/tesseract/tessdata/`.
- **Emulator Results (`Medium_Phone_API_35`, `800x220` high-contrast rendered bitmaps, `v1.0.0`):**
  - ML Kit Devanagari (`नमस्ते निकास 500`): `520 ms` (`208 ms` in `v0.9.0`), exact text recovered.
  - Tesseract `hin` (`नमस्ते निकास 500`, SHA-256 `4c73ffc5...`): `32 ms`, exact text recovered.
  - Tesseract `mar` (`महाराष्ट्र 500`, SHA-256 `0ba3f2d1...`): `16 ms`, exact text recovered.
  - Tesseract `kan` (`ಬೆಂಗಳೂರು 500`, SHA-256 `bd31e6b6...`): `17 ms`, exact text recovered.
  - Tesseract `tam` (`சென்னை 500`, SHA-256 `d02fbec2...`): `14 ms`, exact text recovered.
  - Tesseract `tel` (`హైదరాబాద్‌ 500`, SHA-256 `d10691fd...`): `18 ms`, exact text recovered.
  - Tesseract `mal` (`കൊച്ചി 500`, SHA-256 `bd05cbf1...`): `10 ms`, exact text recovered.
  - Tesseract `ben` (`কলকাতা 500`, SHA-256 `31163084...`): `11 ms`, exact text recovered.
