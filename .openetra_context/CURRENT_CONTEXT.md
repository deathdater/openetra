# Openetra Local Engineering Context

**Current Version:** `1.5.0-assistive-controls-verified`  
**Phase:** Assistive Controls & Floating Companion Complete (Host + Android 15 ARM64 Emulator Verified)  
**Last Updated:** 2026-11-23  
**Git Branch:** `main`  

## Delivered & Verified in `v1.5.0-assistive-controls-verified`
- **All 4 Assistive Capabilities + Shared Core:** Shared router/orchestrator/camera-audio arbiters (SQLite v3), Emergency Assistance (Android Keystore AES-256-GCM + `ACTION_DIAL` + dry-run), Intelligent Flashlight (`TorchCallback` ownership + shared active-frame `meanLuma` + hysteresis/dwell/thermal/battery/180 s limits), Custom Hand Gesture Automation (`hand_landmarks_detector.tflite` on LiteRT `1.4.2` XNNPACK, 84-dim geometric features, enrolment, unknown rejection, emergency opt-in), and Floating Assistive Companion (Android 14/15 `specialUse` FGS, 10-state `FloatingOrbView`, Category A/C background compliance).
- **Android 15 ARM64 Verification (`Medium_Phone_API_35`):**
  - `AssistiveControlsInstrumentedTest`: **3/3 passed** (`0.21 s`) — Keystore AES-GCM (`113` enc bytes, zero plaintext), live LiteRT `1.4.2` hand landmarks (`loadMs=88`, `inferenceMs=34`), `FloatingOrbView` reduced-motion/idle/TalkBack + `FOREGROUND_SERVICE_TYPE_SPECIAL_USE`.
  - Regression suites: `MirageNativeInstrumentedTest` (**1/1**, `1.013 s`), `IndicAndSpecialistInstrumentedTest` (**1/1**, `0.913 s`).
  - `app-release.apk` (`148,818,998` bytes, R8 minified): zero `INTERNET`/`ACCESS_NETWORK_STATE`/`CALL_PHONE` permissions (`aapt2`), cold launch in `1975 ms` (`PID 3750`), zero fatal errors.
- **Documentation:** All 15 Section 15 documents authored under `docs/`.
- **Host Verification:** `flutter analyze` (`No issues found!`), `flutter test -r expanded` (`58/58` passing).
- **Remaining:** Physical retail Android handset validation (live SIM dialer, TalkBack traversal, physical LED/lux sensor, real human hand poses, OEM Doze).
