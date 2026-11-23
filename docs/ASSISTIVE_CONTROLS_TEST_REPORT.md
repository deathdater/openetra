# Assistive Controls Test & Verification Report

**Product:** Openetra (`v1.5.0-assistive-controls-verified`)  
**Date:** 2026-11-23

---

## 1. Host Static Analysis & Unit/Widget Test Suites

- **Command:** `/Users/deathdater/development/flutter/bin/flutter analyze`
  - **Result:** `No issues found!`
- **Command:** `/Users/deathdater/development/flutter/bin/flutter test -r expanded`
  - **Result:** `58/58` tests passed (`0` failed, `0` skipped), including:
    - `test/core/assistive/shared_architecture_test.dart` (action router, availability, orchestrator, camera lease, audio arbitrator, SQLite `v2 -> v3` migration)
    - `test/features/emergency/emergency_assistance_test.dart` (contact validation, PII redaction, confirmation/cancel, dry-run zero-dial, airplane/missing-dialer degradation, `SettingsBloc` wipe, UI widget flow)
    - `test/features/flashlight/intelligent_flashlight_test.dart` (hysteresis, dwell, debounce, 180 s cutoff, battery/thermal pause, external torch refusal, shared camera `meanLuma`, UI widget flow)
    - `test/features/gestures/gesture_evaluation_test.dart` (100/100 TP, 0 FP, 100% unknown rejection, noisy/collision rejection, temporal voting, cooldown, `TaskOrchestrator` routing, emergency opt-in safeguard, UI widget flow)
    - `test/features/floating_companion/floating_companion_test.dart` (permission refusal/revocation, Category A vs C gating, `FeedbackDispatcher` sink forwarding, UI widget flow)
    - All `40` pre-existing v1.0.0 tests (including `HomeScreen` accessibility and `SettingsScreen` wipe confirmation) — **zero regressions**.

## 2. Android 15 ARM64 Emulator Instrumentation Suites (`Medium_Phone_API_35`)

| Suite | Command | Result | Key Observed Metrics |
|---|---|---|---|
| `AssistiveControlsInstrumentedTest` | `adb shell am instrument -w -e class com.openetra.app.AssistiveControlsInstrumentedTest com.openetra.app.test/androidx.test.runner.AndroidJUnitRunner` | **OK (3 tests)** in `0.21 s` | Keystore AES-256-GCM roundtrip (`113` enc bytes, 0 plaintext); LiteRT `1.4.2` hand landmarks load `88 ms` + inference `34 ms`; `FloatingOrbView` reduced-motion/idle/TalkBack + `FOREGROUND_SERVICE_TYPE_SPECIAL_USE` verified |
| `MirageNativeInstrumentedTest` | `adb shell am instrument -w -e class com.openetra.app.MirageNativeInstrumentedTest com.openetra.app.test/androidx.test.runner.AndroidJUnitRunner` | **OK (1 test)** in `1.013 s` | Zero regression in native Cactus Mirage 2-bit VLM |
| `IndicAndSpecialistInstrumentedTest` | `adb shell am instrument -w -e class com.openetra.app.IndicAndSpecialistInstrumentedTest com.openetra.app.test/androidx.test.runner.AndroidJUnitRunner` | **OK (1 test)** in `0.913 s` | Zero regression in Indic OCR (7 packs), Silero VAD, ML Kit Barcode, LiteRT |

## 3. Release APK Build, Permissions & Cold-Launch Smoke Test

- **Command:** `/Users/deathdater/development/flutter/bin/flutter build apk --release --target-platform android-arm64`
- **Artifact:** `build/app/outputs/flutter-apk/app-release.apk` (`148,818,998` bytes, R8 `minifyEnabled = true`, `shrinkResources = true`)
- **Permission Audit (`aapt2 dump permissions`):** `CAMERA`, `RECORD_AUDIO`, `VIBRATE`, `SYSTEM_ALERT_WINDOW`, `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE`, `POST_NOTIFICATIONS`. **Zero `INTERNET`, zero `ACCESS_NETWORK_STATE`, zero `CALL_PHONE`.**
- **Cold-Launch Smoke Test (`Medium_Phone_API_35`):** `LaunchState: COLD`, `TotalTime: 1975 ms`, `WaitTime: 1980 ms`, running PID `3750`, zero `AndroidRuntime:E` fatal exceptions.

## 4. Not Yet Physically Validated

Physical-device testing on retail Android 12–15 handsets has **not** been executed in this environment (live TalkBack traversal, real cellular `ACTION_DIAL`, physical LED torch + `Sensor.TYPE_LIGHT` thermal rise, real human hand poses under varied lighting, and OEM battery-optimization behavior).
