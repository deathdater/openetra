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

## 3. Android ARM64 Emulator Measurements
*(To be populated in Milestone `v0.6.0` after executing live `Medium_Phone_API_35` ARM64 APK verification.)*

## 4. Physical Android Device Measurements
*(Pending physical entry-level, mid-range, and flagship Android device testing in Phase 7.)*
