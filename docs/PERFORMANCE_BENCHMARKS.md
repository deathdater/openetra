# Performance Benchmarks

## 1. Provisional Engineering Targets (Section 17)
- Core offline functionality: **100%** after provisioning
- Scene description: **P95 < 3.0 s** on defined hardware
- Basic detection: **P95 < 500 ms** where supported
- OCR single page: **P95 < 5.0 s**
- Speech initiation after result: **P95 < 1.0 s**
- Non-blocking UI thread: **0 ms inference on Flutter/Main UI thread**

---

## 2. Measured Host Baseline (Apple Silicon arm64, macOS 15.1, Cactus 4.1.4 CPU)
*(Direct measurement from `harness/mirage_probe`; NOT Android phone hardware.)*

| Workload | Cold Load (ms) | Run 0 (ms) | Warm Run 1 (ms) |
|---|---:|---:|---:|
| COCO `231049` (`427x640`, full default w/ masks) | `24.0` | `258.3` | `152.3` |
| COCO `231049` (`427x640`, selective no-mask) | `18.1` | `174.7` | — |
| COCO `231049` (`427x640`, `sections: ["text"]`) | `15.3` | `136.4` | — |
| COCO `231049` (`427x640`, `form` 3-choice) | `15.7` | `53.7` | — |
| COCO `139` (`640x426`, selective living room) | `15.2` | `244.8` | `219.6` |
| COCO `785` (`640x425`, selective skiing) | `16.3` | `231.3` | `293.3` |
| COCO `1000` (`640x480`, selective park) | `14.6` | `172.9` | `242.4` |
| COCO `2153` (`640x480`, selective baseball) | `15.1` | `241.2` | `171.2` |

---

## 3. Measured Android ARM64 Emulator Verification (`Medium_Phone_API_35`, Android 15, `arm64-v8a`, 4 CPU threads)
*(Direct reproducible measurement from `MirageNativeInstrumentedTest` and `IndicAndSpecialistInstrumentedTest` running `libopenetra_mirage.so`, `libsherpa-onnx-jni.so`, `libtesseract.so`, ML Kit Devanagari/Barcode, and `computeCropDescriptor96` inside Android 15 `arm64-v8a` emulator; emulator CPU scheduling overhead differs from physical SoC NPU/CPU hardware.)*

### 3.1 Mirage C++ JNI Baseline & Reload Measurements
| Metric / Workload | Measured Result | Verified Output |
|---|---:|---|
| Bundled `mirage.cact` SHA-256 check (`21,611,043 B`) | Pass | `4249a0f7515272ff76b9414bec17d7e7daf84b15b66c7fb4f17fce1e66f9f237` |
| Native `cactus_load` (`v0.6.0` / `v0.9.0` / `v1.0.0`) | `57.09 ms` / `85.43 ms` / `107.16 ms` | `models_mask = 4` (`CACTUS_VISION`) |
| COCO `231049` (`427x640`, scene+objects+text+relations) — Call 1 (`v0.6.0` / `v0.9.0` / `v1.0.0`) | `961.40 ms` / `285.59 ms` / `363.73 ms` | `suburban street`, `stop sign` (`0.639`), `ARRET` (`0.870`) |
| COCO `231049` (`427x640`, scene+objects+text+relations) — Call 2 (`v0.6.0` / `v0.9.0` / `v1.0.0`) | `1431.23 ms` / `291.42 ms` / `230.52 ms` | `meanLuma=106.2`, `laplacianVar=4684.2` |
| COCO `139` (`640x426`, scene+objects+text+relations) (`v0.6.0` / `v0.9.0` / `v1.0.0`) | `1429.90 ms` / `298.76 ms` / `303.86 ms` | `living room`, 11 `chair` detections (`id=6`), `dining table`, `rug` |
| Mirage `form` 3-choice (`v0.9.0` / `v1.0.0`, COCO `231049`) | `120.65 ms` / `107.71 ms` | `stop = 0.7898`, `yield = 0.0690`, `speed limit = 0.0440`, `- = 0.0972` |
| Cold Flutter App Launch (`app-debug.apk`, `v0.6.0`) | `5425 ms` | Zero uncaught exceptions; Dart VM initialized cleanly |
| Cold R8 Release Launch (`app-release.apk`, `142,993,414 B`, `v1.0.0`) | `2560 ms` | Process PID `8429` verified running after 3s; zero fatal JNI/R8 errors |

### 3.2 All-8-Language Indic OCR, VAD, Barcode, Embeddings & LiteRT XNNPACK (`v1.0.0`, total runner `1.75 s`)
| Engine / Workload | Measured Result | Verified Output |
|---|---:|---|
| ML Kit Devanagari OCR (`16.0.1`, bundled offline, `800x220` bitmap) | `520 ms` (`208 ms` `v0.9.0`) | `नमस्ते निकास 500` (exact match) |
| Tesseract `4.9.0` Hindi (`hin.traineddata`, `1,122,751 B`) | `32 ms` | `नमस्ते निकास 500` (exact match) |
| Tesseract `4.9.0` Marathi (`mar.traineddata`, `2,118,233 B`) | `16 ms` | `महाराष्ट्र 500` (exact match) |
| Tesseract `4.9.0` Kannada (`kan.traineddata`, `3,608,331 B`) | `17 ms` | `ಬೆಂಗಳೂರು 500` (exact match) |
| Tesseract `4.9.0` Tamil (`tam.traineddata`, `3,237,963 B`) | `14 ms` | `சென்னை 500` (exact match) |
| Tesseract `4.9.0` Telugu (`tel.traineddata`, `2,769,654 B`) | `18 ms` | `హైదరాబాద్‌ 500` (exact match) |
| Tesseract `4.9.0` Malayalam (`mal.traineddata`, `5,275,996 B`) | `10 ms` | `കൊച്ചി 500` (exact match) |
| Tesseract `4.9.0` Bengali (`ben.traineddata`, `855,841 B`) | `11 ms` | `কলকাতা 500` (exact match) |
| `sherpa-onnx 2.0.3` Silero VAD (`silero_vad.int8.onnx`, 2.0 s @ 16 kHz) | `19 ms` | `speechDetected=true`, `segmentCount=1` |
| ML Kit Barcode (`17.3.0`, bundled offline, `500x200` Code-128) | `53 ms` | `rawValue=8901058851234`, `format=1` |
| 96-dim Visual Crop Embedding (`computeCropDescriptor96` on `stop_sign`) | `21.03 ms` | L2 norm `1.0000`, self-cosine `1.0000`, distinct crop cosine `0.8886` |
| LiteRT `1.4.2` XNNPACK (`litert_add_smoke.tflite` test-only, 192 elems) | `1.02 ms` | `(1.5 + 1.5) + 1.5 = 4.5` verified across all elements |

---

## 4. Physical Android Device & Remaining Pack Measurements
*(Physical Android entry-level, mid-range, and flagship battery/thermal/NPU testing, plus downloaded `IndicConformer` ASR packs and trained currency/depth `.tflite` weights, remain pending in Phase 7–8.)*
