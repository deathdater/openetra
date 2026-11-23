# Low-Power Optimization & Device Resource Management

## 1. Operating Modes & Adaptive Policy

| Operating Mode | Camera Cadence | Mirage Sections | Mirage Fields | Threads | Intended Scenario |
|---|---|---|---|---|---|
| **Eco** | On-demand or `2500 ms` | `scene`, `objects` | `bbox`, `score`, `position` | `2` | Battery saving (`<20%`) or warm thermal |
| **Balanced** | On-demand or `1200 ms` | `scene`, `objects`, `relations`, `text` | `bbox`, `score`, `position`, `description` | `0` (auto) | Everyday scene exploration |
| **Reading** | Single capture / `1500 ms` | `text` | `bbox`, `score` | `0` (auto) | Document & sign reading |
| **Object Search** | `1000 ms` | `objects` | `bbox`, `score`, `position`, `description` | `0` (auto) | Locating personal belongings |
| **Hazard Awareness** | `450–700 ms` (adaptive) | `objects`, `regions`, `text` | `bbox`, `score`, `position`, `description` | `0` (auto) | Active walking assistance |
| **Idle** | Camera unbound | None | None | `0` | Backgrounded / paused |

---

## 2. Core Low-Power Techniques
1. **Lazy Model Loading & Single-Instance Reuse:** Only load `mirage.cact` when visual inference is requested; keep specialist packs unloaded until selected.
2. **Frame Backpressure (`STRATEGY_KEEP_ONLY_LATEST`):** CameraX drops queued frames if native inference is still busy, preventing stale frame buildup and OOM pressure.
3. **Selective Inference Omission:** Mask generation (`polygons` / `bitmap`) is disabled during continuous scenes and hazards because host probing proved polygon decoding more than doubles runtime (`372 ms` vs `174 ms`).
4. **Thermal & Battery Throttling (`DeviceResourceManager`):**
   - Monitors `PowerManager.currentThermalStatus`, `BatteryManager`, and `ActivityManager.MemoryInfo`.
   - Under `MODERATE`/`SEVERE` thermal state or `<15%` non-charging battery, increases frame intervals and caps threads—and **explicitly notifies the user** if Hazard Awareness cadence must slow down.
5. **Off-UI Execution:** Native C++ runs strictly on Kotlin's single-thread worker (`Executors.newSingleThreadExecutor`), ensuring 60 fps TalkBack responsiveness.
