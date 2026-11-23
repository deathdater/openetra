# Assistive Controls & Floating Companion — Implementation Status

**Version:** `1.5.0-assistive-controls-verified`  
**Last Updated:** 2026-11-23

---

## Feature-by-Feature Status Matrix

| Phase / Feature | Status | Evidence | Remaining Gap |
|---|---|---|---|
| **Phase 0:** Repository Reconnaissance & Impact Analysis | **Implemented and verified** | `docs/ASSISTIVE_CONTROLS_IMPACT_ANALYSIS.md`, baseline `40/40` tests | None |
| **Phase 1:** Shared Router, Orchestrator, Camera/Audio Arbiters, SQLite v3 | **Implemented and verified** | `lib/core/assistive/*`, `OpenetraDatabase` v3, `shared_architecture_test.dart` | None |
| **Phase 2:** Emergency Assistance (Keystore AES-256-GCM + `ACTION_DIAL` + dry-run) | **Implemented and verified** (code + emulator Keystore); **Implemented but not yet physically validated** (live SIM dialer + TalkBack) | `EmergencyAssistancePlugin.kt`, `lib/features/emergency/*`, `emergency_assistance_test.dart`, `AssistiveControlsInstrumentedTest` | Physical SIM dialer handoff & live TalkBack check |
| **Phase 3–4:** Manual & Opt-In Automatic Flashlight | **Implemented and verified** (policy + ownership + UI); **Implemented but not yet physically validated** (physical LED + lux sensor) | `FlashlightPlugin.kt`, `CameraXCaptureManager.kt`, `lib/features/flashlight/*`, `intelligent_flashlight_test.dart` | Physical handset LED + `Sensor.TYPE_LIGHT` thermal/lux check |
| **Phase 5–7 & 10:** Custom Hand Gesture Automation + Emergency Opt-In | **Implemented and verified** (LiteRT `1.4.2` `34 ms` on emulator + synthetic held-out eval); **Implemented but not yet physically validated** (real human camera hands) | `HandGesturePlugin.kt`, `hand_landmarks_detector.tflite`, `lib/features/gestures/*`, `gesture_evaluation_test.dart`, `AssistiveControlsInstrumentedTest` | Real-camera human hand trials across lighting/skin tones |
| **Phase 8–9:** Floating Assistive Companion + Android 14/15 Background Policy | **Implemented and verified** (manifest `specialUse`, `FloatingOrbView`, BLoC, Category A/C policy); **Implemented but not yet physically validated** (multi-app OEM overlay + TalkBack drag) | `android/.../floating/*`, `lib/features/floating_companion/*`, `floating_companion_test.dart`, `AssistiveControlsInstrumentedTest` | Physical Android 12–15 multi-app overlay & OEM Doze testing |
| **Phase 11:** Release Hardening, Docs & Regression | **Implemented and verified** (58/58 host tests, 5/5 emulator instrumentation tests, zero-network `app-release.apk`, 15/15 Section 15 docs) | `app-release.apk` (`148.8 MB`), `aapt2`, `ASSISTIVE_CONTROLS_TEST_REPORT.md` | Physical-device battery & TalkBack sign-off |

## Status Legend

- **Implemented and verified:** Code built and passing automated host and/or Android 15 ARM64 emulator verification.
- **Implemented but not yet physically validated:** Implemented and unit/emulator-tested, awaiting physical handset QA.
- **Partially implemented:** None.
- **Proposed:** Optional two-stage palm ROI detector (`hand_detector.tflite`) for far-field gestures if physical trials require it.
- **Blocked by platform/policy:** Covert background camera/mic capture and silent `CALL_PHONE` emergency dialing are intentionally disallowed.
