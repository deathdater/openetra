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
*(Direct reproducible measurement from `MirageNativeInstrumentedTest` running `libopenetra_mirage.so` + `libcactus.a` + SHA-256-verified `mirage.cact` inside Android 15 `arm64-v8a` emulator; emulator CPU scheduling overhead differs from physical SoC NPU/CPU hardware.)*

| Metric / Workload | Measured Result | Verified Output |
|---|---:|---|
| Bundled `mirage.cact` SHA-256 check (`21,611,043 B`) | Pass | `4249a0f7515272ff76b9414bec17d7e7daf84b15b66c7fb4f17fce1e66f9f237` |
| Native `cactus_load` (`ANDROID_MIRAGE_LOAD_MS`) | `57.09 ms` | `models_mask = 4` (`CACTUS_VISION`) |
| COCO `231049` (`427x640`, selective scene+objects+text+relations) — Call 1 | `961.40 ms` | `suburban street`, `stop sign` (`0.639`), `ARRET` (`0.870`) |
| COCO `231049` (`427x640`, selective scene+objects+text+relations) — Call 2 | `1431.23 ms` | `meanLuma=106.2`, `laplacianVar=4684.2` |
| COCO `139` (`640x426`, selective scene+objects+text+relations) | `1429.90 ms` | `living room`, 11 `chair` detections (`id=6`), `dining table`, `rug` |
| Cold Flutter App Launch (`com.openetra.app/.MainActivity`) | `5425 ms` | Zero uncaught exceptions; Dart VM initialized cleanly |

---

## 4. Physical Android Device Measurements
*(Pending physical entry-level, mid-range, and flagship Android device battery/thermal/latency testing in Phase 7.)*
