# Openetra Local Engineering Context

**Current Version:** `1.3.0-gesture-automation`  
**Phase:** Assistive Controls Milestone 3 (Phases 5–7) — Custom Hand Gesture Automation  
**Last Updated:** 2026-11-23  
**Git Branch:** `main`  

## Delivered in `v1.3.0-gesture-automation`
- **Model Asset & Registry:** Extracted official Apache-2.0 `hand_landmarks_detector.tflite` (`5,478,949 B`, SHA-256 `6acda74af3fbf40e68265c20c7394b2bad81a16a481dcd79ad7a081887c3d6b9`) from `hand_landmarker.task` into `assets/models/gesture/hand_landmarks_detector.tflite`; registered in `pubspec.yaml` and `AIModelRegistry` (`ModelTask.handGesture`).
- **Native LiteRT Plugin:** Implemented `HandGesturePlugin.kt` (`com.openetra.app/gesture`) reusing bundled LiteRT `1.4.2` XNNPACK (zero new Gradle deps), SHA-256 verification, lazy load/unload, 21 3D landmarks + presence/handedness output, and zero video retention.
- **Flutter Gesture Domain & UI:** Implemented `HandLandmarkFeatureExtractor` (palm-centered 84-dim L2-unit descriptor), `GestureEnrollmentEngine` (5-sample intra-consistency & inter-gesture collision checks), `GestureRecognitionEngine` (unknown rejection, top-2 margin, 3/4 temporal voting, cooldown), `GestureAutomationBloc` (strictly routing via `TaskOrchestrator` with explicit `emergencyGestureOptIn` safeguard), and `GestureAutomationScreen`.
- **Verification:** `flutter analyze` (`No issues found!`) and `flutter test -r expanded` (`56/56` passing; synthetic held-out eval: 100/100 TP, 0 FP, 100% unknown rejection across 60 negative poses).
