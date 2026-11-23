# Mirage Model Evaluation

## 1. Provenance & Published Reference
- **Model:** `Cactus-Compute/mirage` (commit `76c1e9e53381aca8fc3843c636216c96ff220122`, `mirage.cact`, 21,611,043 B, 2-bit quantised, ~51.3M parameters, Apache-2.0).
- **Vendor Reference (Galaxy S26, Cactus Blog):** 74 ms NPU / 107 ms CPU *(external vendor claim; not yet independently measured on Galaxy S26 hardware in this repo).*

---

## 2. Reproducible Host CPU Measurements (Apple Silicon arm64, macOS 15.1)

Measured locally using `harness/mirage_probe` compiled against Cactus `4.1.4` (`rt/macos/libcactus.a`):

| COCO Image | Resolution | Options Preset | Cold Load (ms) | Run 0 (ms) | Warm Run 1 (ms) | Output Summary |
|---|---|---|---:|---:|---:|---|
| `000000231049` (Street stop sign) | `427x640` | Full default (incl. masks) | `24.0` | `258.3` | `152.3` | `suburban street`, 8 objs, 1 text (`ARRET`), 2 rels |
| `000000231049` | `427x640` | Selective (no masks, no text) | `18.1` | `174.7` | — | 8 objs (`stop sign`, `car`, `pole`, `tree`, `grass`) |
| `000000231049` | `427x640` | `sections: ["text"]` | `15.3` | `136.4` | — | `ARRET` (`score: 0.871`) |
| `000000231049` | `427x640` | `form` (3-class sign enum) | `15.7` | `53.7` | — | `"stop"` (`p=0.7713`) |
| `000000231049` | `427x640` | `mask_format: "bitmap"` | `15.5` | `241.5` | — | RLE bitmaps |
| `000000231049` | `427x640` | `mask_format: "polygons"` | `17.3` | `372.0` | — | Polygon arrays |
| `000000000139` (Living room) | `640x426` | Selective (scene+objs+rels+events) | `15.2` | `244.8` | `219.6` | `living room`, 23 objs (11 chairs id=6), 3 rels |
| `000000000785` (Skiing) | `640x425` | Selective | `16.3` | `231.3` | `293.3` | `scene: null`, 18 objs, 17 rels |
| `000000001000` (Park) | `640x480` | Selective | `14.6` | `172.9` | `242.4` | `park`, 13 objs, 5 rels, 5 events |
| `000000002153` (Baseball) | `640x480` | Selective | `15.1` | `241.2` | `171.2` | `baseball field`, 6 objs, 3 rels |

---

## 3. Key Findings Driving Openetra Design
1. **Mask Omission Cuts Latency:** Omitting `mask` unless contour extraction is strictly needed saves ~100–200 ms per frame on CPU (`174.7 ms` vs `372.0 ms` polygons).
2. **Text-Only and Form Requests are Fast:** `text` only (`136.4 ms`) and `form` (`53.7 ms`) justify dedicated lightweight `SmartReader` / confirmation query profiles.
3. **Entity Grouping & Relation Filtering Required:** Mirage shares entity `id` across multiple boxes (11 chairs with `id: 6` in `000000000139`), and occasionally outputs implausible relations (`rug on table`) or `scene: null`. `SceneUnderstandingEngine` handles deduplication and defensive parsing.
4. **Android ARM64 Emulator Verification (`Medium_Phone_API_35`, Android 15, `arm64-v8a`):**
   - Executed `MirageNativeInstrumentedTest` directly against `libopenetra_mirage.so` + `libcactus.a` + `mirage.cact` inside Android 15 `arm64-v8a` emulator (4 threads):
     - SHA-256 check passed (`4249a0f7515272ff76b9414bec17d7e7daf84b15b66c7fb4f17fce1e66f9f237`), `cactus_load`: `57.09 ms` (`mask = 4`).
     - `stop_sign_231049.jpg`: `961.40 ms` (call 1) / `1431.23 ms` (call 2); detected `suburban street`, `stop sign` (`0.639`), `ARRET` (`0.870`), `attached_to`, `standing_on`.
     - `living_room_139.jpg`: `1429.90 ms`; detected `living room`, 11 `chair` instances sharing `id: 6`, `dining table`, `rug`.
     - Note: `Medium_Phone_API_35` emulator numbers reflect virtualized ARM64 execution; physical device NPU/CPU latency, RAM, and battery benchmarks remain Phase 7 work.
