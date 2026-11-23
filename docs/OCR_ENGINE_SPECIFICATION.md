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
If a user in Reading mode requests Hindi or Kannada document reading before the offline Indic OCR pack is downloaded, `OcrRouter` honestly announces that only Latin OCR (Mirage) is currently active locally and directs the user to **Model Manager** to install the offline pack.
