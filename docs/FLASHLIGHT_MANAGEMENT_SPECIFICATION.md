# Flashlight Management Specification

**Product:** Openetra  
**Status Summary:** Manual and opt-in automatic flashlight architecture implemented and verified via host tests; physical camera-LED thermal behavior and OEM `TorchCallback` variance remain **Implemented but not yet physically validated**.

---

## 1. Purpose & Safety Boundaries

Provides reliable manual flashlight toggling and opt-in automatic low-light illumination during active authorized Openetra tasks (e.g., scene description, reading, hazard cue checks) to improve image luminance.

- **Not a mobility guarantee:** Torch illumination never guarantees obstacle detection or safe path traversal.
- **Strict ownership:** Openetra tracks `CameraManager.TorchCallback` and never turns off a flashlight owned by another app or the user's Android Quick Settings tile.
- **Single camera owner:** When CameraX is active, torch control routes through `CameraXCaptureManager.setCameraTorch(enabled)` and shares active-frame `meanLuma` without ever opening a second camera session.

## 2. Policy Parameters (`lib/features/flashlight/domain/flashlight_policy.dart`)

| Parameter | Default | Purpose |
|---|---|---|
| `autoModeEnabled` | `false` (opt-in) | Never activates torch automatically unless user opts in |
| `lowLightTurnOnLux` / `brightTurnOffLux` | `15.0` / `45.0` lux | Hysteresis dead-band prevents flicker |
| `lowLightTurnOnLuma` / `brightTurnOffLuma` | `48.0` / `90.0` (0–255) | Active-frame luminance fallback when no ambient light sensor is present |
| `transitionDebounce` | `1500 ms` | Requires sustained dark/bright reading before switching |
| `minDwell` | `4000 ms` | Minimum time between automatic transitions |
| `maxContinuousOn` | `180 s` | Safety cutoff pauses auto mode to protect battery and LED thermals |
| `lowBatteryCutoffPercent` | `15%` (unplugged) | Pauses auto mode when battery <= 15% and not charging |
| Thermal cutoff | `ThermalState.severe` or `critical` | Pauses auto mode and turns off Openetra-owned torch |

## 3. Repository Locations

- Native bridge: `android/app/src/main/kotlin/com/openetra/app/flashlight/FlashlightPlugin.kt` (`com.openetra.app/flashlight`), `android/app/src/main/kotlin/com/openetra/app/camera/CameraXCaptureManager.kt`
- Flutter domain & UI: `lib/features/flashlight/domain/flashlight_policy.dart`, `lib/features/flashlight/domain/intelligent_flashlight_controller.dart`, `lib/features/flashlight/data/native_flashlight_gateway.dart`, `lib/features/flashlight/presentation/flashlight_settings_screen.dart`

## 4. Verification Classification

- **Implemented and verified:** Hysteresis, dwell, debounce, 180 s cutoff, low-battery/thermal pause, external torch refusal (`EXTERNAL_TORCH_OWNER`), active-camera `meanLuma` sharing with single camera session (`startCount == 1`), session-end cleanup, and settings UI (`test/features/flashlight/intelligent_flashlight_test.dart`).
- **Implemented but not yet physically validated:** Physical LED torch hardware activation alongside live CameraX capture, real `Sensor.TYPE_LIGHT` lux calibration across OEM handsets, and thermal rise measurements during 180 s illumination.
- **Partially implemented / Proposed / Blocked:** None.
