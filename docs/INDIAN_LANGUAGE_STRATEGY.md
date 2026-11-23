# Indian Language Strategy

## 1. Language Scope & Validation Priority
- **Phase 1–4 Initial Priority:** English (`en-IN`), Hindi (`hi-IN`), Kannada (`kn-IN`).
- **Modular Language Packs (Phase 5+):** Tamil (`ta-IN`), Telugu (`te-IN`), Malayalam (`ml-IN`), Marathi (`mr-IN`), Bengali (`bn-IN`).

---

## 2. Empirical Research Findings (Phase 0)

### 2.1 Indic OCR
- **Mirage Built-In OCR:** Restricted to 306 Latin/Extended-A codepoints; zero support for Devanagari, Kannada, Tamil, Telugu, Malayalam, or Bengali.
- **PaddleOCR PP-OCRv5 Mobile (`PaddlePaddle/PaddleOCR` `main`, Apache-2.0):**
  - Verified mobile recognisers: `devanagari_PP-OCRv5_mobile_rec` (Hindi/Marathi/Sanskrit), `ta_PP-OCRv5_mobile_rec` (Tamil), `te_PP-OCRv5_mobile_rec` (Telugu), `en_PP-OCRv5_mobile_rec` (English).
  - **Kannada Clarification:** Inspection of `ppocr/utils/dict/ka_dict.txt` confirmed 72 Kannada characters (`U+0C80..U+0CFF`), 54 Latin letters, 10 digits, and unexpected leading lines (`k a _ i m g / 1 2`). `ka_dict.txt` represents Kannada (`ka`), **not** Georgian, but PaddleOCR only ships `ka_PP-OCRv3_mobile_rec` (not v5) and provides no Bengali or Malayalam PP-OCRv5 mobile recognisers.
- **Tesseract `tessdata_fast` (Apache-2.0):**
  - Verified compact integer LSTM models across all 8 languages: `ben` `0.82 MB`, `hin` `1.07 MB`, `mar` `2.02 MB`, `tel` `2.64 MB`, `tam` `3.09 MB`, `kan` `3.44 MB`, `eng` `3.92 MB`, `mal` `5.03 MB`.
- **Google ML Kit Text Recognition v2:** Supports Latin + Devanagari (`~4 MB` bundled), but lacks Kannada, Tamil, Telugu, Malayalam, and Bengali.

### 2.2 Offline Indian ASR
- **AI4Bharat IndicConformer (MIT):** ~30M-parameter Conformer supporting 22 scheduled Indian languages; community INT8 ONNX exports (`~180–190 MB` per language pack for `sherpa-onnx` Apache-2.0) run offline on Android `arm64-v8a` with `16 kHz` mono PCM + Silero VAD (`~1.8 MB`, MIT).
- **Compact Whisper (`tiny`/`base` fine-tunes):** Evaluated only where Hinglish/Kanglish code-switching outperforms single-language Conformer packs.

### 2.3 Offline Indian TTS & Translation Policy
- **Android System Offline TTS Check:** Never assume system TTS works offline. Openetra queries `TextToSpeech.getVoices()` on Android and checks `!voice.isNetworkConnectionRequired && !voice.features.contains(TextToSpeech.Engine.KEY_FEATURE_NOT_INSTALLED)` per locale.
- **Meta MMS VITS (`vits-mms-*`):** Licensed `CC-BY-NC 4.0` (non-commercial) — **explicitly excluded** from production shipping packages.
- **Piper TTS Voices (`piper-voices`):** Although the `piper-voices` repository carries an MIT marker for tooling/metadata, individual voice `.onnx` checkpoints (such as `hi_IN-rohan` or `hi_IN-pratham`) inherit upstream dataset licences (e.g., IIT Madras IndicTTS). Each candidate voice's per-folder `MODEL_CARD` must be audited before bundling.
- **Translation Policy:** Never force multi-stage translation for hazard warnings or basic descriptions. Safety alerts and core UI confirmations are authored natively in English, Hindi, and Kannada and spoken directly in the selected offline language.

---

## 3. Verified Phase 5–6 Implementation (`v0.9.0`)
- **Direct Native Trilingual Localization:** `OpenetraLocalizer` authors English (`en-IN`), Hindi (`hi-IN`), and Kannada (`kn-IN`) phrases natively across `SceneUnderstandingEngine`, `HazardIntelligenceEngine`, `SafetySpeechGuard`, `CurrencyRecognitionService`, `OpenetraCoordinator`, and `HomeScreen`.
- **Bundled Indic OCR (`arm64-v8a` & `armeabi-v7a`):** Verified offline execution on `Medium_Phone_API_35` Android 15 emulator with ML Kit Devanagari `16.0.1` (`208 ms`, `"नमस्ते निकास 500"`), Tesseract `4.9.0` `hin.traineddata` (`27 ms`, `"नमस्ते निकास 500"`), and `kan.traineddata` (`14 ms`, `"ಬೆಂಗಳೂರು 500"`).
- **Offline Speech Boundary & Pluggable ASR:** Bundled `sherpa-onnx 2.0.3` + `silero_vad.int8.onnx` (`14 ms` verified on `Medium_Phone_API_35`), `OfflineRecognizer` (`OfflineNemoEncDecCtcModelConfig`) for SHA-256-verified external `IndicConformer` packs (`loadAsrPack`), and Android OS `SpeechRecognizer.isOnDeviceRecognitionAvailable` fallback check. On-device `IndicConformer` pack benchmarking and physical device Indian-speaker ASR trials remain pending pack provisioning and Phase 7–8 field testing.
