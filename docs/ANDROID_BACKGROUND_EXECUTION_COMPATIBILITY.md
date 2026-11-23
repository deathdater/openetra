# Android Background Execution Compatibility

**Product:** Openetra  
**Supported Range:** Android 8.0 (`minSdk 26`) through Android 15 (`targetSdk 35`)

---

## 1. Platform Compliance Matrix

| Android Version / Constraint | Openetra Behavior | Compliance Status |
|---|---|---|
| **Android 11+ (API 30+)** Background camera/mic restrictions | Category C camera/mic tasks never start from background; `FloatingCompanionService` brings `MainActivity` to foreground with `EXTRA_ASSISTIVE_ACTION` | **Implemented and verified** (policy + trampoline) |
| **Android 12+ (API 31+)** Foreground service launch restrictions | `FloatingCompanionService` starts only from explicit user action in foreground Settings UI | **Implemented and verified** |
| **Android 13+ (API 33+)** `POST_NOTIFICATIONS` runtime permission | Declared in manifest; notification channel `openetra_floating_companion` uses `IMPORTANCE_LOW` | **Implemented and verified** (manifest); physical OEM prompt flow **Implemented but not yet physically validated** |
| **Android 14–15 (API 34–35)** Typed foreground services (`specialUse`) | Declares `FOREGROUND_SERVICE_SPECIAL_USE`, `android:foregroundServiceType="specialUse"`, and `PROPERTY_SPECIAL_USE_FGS_SUBTYPE`; calls `startForeground(..., FOREGROUND_SERVICE_TYPE_SPECIAL_USE)` | **Implemented and verified** on Android 15 ARM64 emulator (`AssistiveControlsInstrumentedTest`) |
| **Android 14–15** `SYSTEM_ALERT_WINDOW` & privacy indicators | Checks `Settings.canDrawOverlays()` before adding overlay; never suppresses OS camera/mic privacy dots | **Implemented and verified** (code & tests); multi-app OEM test **Implemented but not yet physically validated** |
| **Android 11+** Package visibility (`<queries>`) | Declares `ACTION_DIAL` (`tel:`), `TTS_SERVICE`, `RecognitionService` in `<queries>` | **Implemented and verified** |

## 2. OEM Battery Optimization Notes

Aggressive OEM process managers (Samsung One UI, Xiaomi MIUI/HyperOS, OnePlus OxygenOS, Vivo/Oppo) may kill long-running foreground services when battery optimization is strict. Openetra never attempts to bypass Doze/App Standby covertly; if the service is stopped by the OS, `FloatingCompanionBloc` detects `serviceRunning == false` on next open and reports state honestly.

## 3. Verification Classification

- **Implemented and verified:** Android 15 (`API 35`) manifest compliance, `specialUse` service type, release APK zero-network permissions, cold launch (`1975 ms`), and host background policy tests.
- **Implemented but not yet physically validated:** Physical Android 12/13/14/15 OEM Doze/battery-saver stress testing.
- **Blocked by platform rules:** Covert background camera/microphone capture from an overlay service is permanently disallowed by Android 14/15 and Openetra's privacy principles.
