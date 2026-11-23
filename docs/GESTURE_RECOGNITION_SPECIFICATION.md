# Custom Hand Gesture Recognition Specification

**Product:** Openetra  
**Status Summary:** End-to-end offline hand-landmark inference, 84-dim feature extraction, enrolment, matching, and action routing implemented and verified on host + Android 15 ARM64 emulator; real human hand-pose evaluation on physical cameras remains **Implemented but not yet physically validated**.

---

## 1. Architecture & Privacy Boundaries

- **Opt-in foreground only:** Disabled by default (`gesture_automation_enabled = false`). Never runs continuous background camera capture.
- **Zero video retention:** Only 84-dimensional L2-normalized geometric landmark descriptors are stored in SQLite (`custom_gestures`, schema v3). Raw camera frames are discarded immediately after inference.
- **Zero new Gradle dependencies:** Reuses Openetra's bundled Apache-2.0 `com.google.ai.edge.litert:litert:1.4.2` runtime with XNNPACK (`2` threads).
- **Shared action routing:** Validated gestures dispatch exclusively via `TaskOrchestrator.dispatch(actionId, sourceTrigger: 'custom_gesture', fromBackground: false)` — zero domain logic is duplicated.

## 2. Bundled Model Asset

- **Asset:** `assets/models/gesture/hand_landmarks_detector.tflite`
- **Provenance:** Extracted from official MediaPipe `hand_landmarker/float16/1/hand_landmarker.task` (Apache-2.0)
- **Size:** `5,478,949` bytes
- **Pinned SHA-256:** `6acda74af3fbf40e68265c20c7394b2bad81a16a481dcd79ad7a081887c3d6b9`
- **Verified TFLite Tensors:** Input `input_1 [1, 224, 224, 3] FLOAT32`; Outputs `Identity [1, 63] FLOAT32` (21x3 landmarks), `Identity_1 [1, 1] FLOAT32` (hand presence), `Identity_2 [1, 1] FLOAT32` (handedness), `Identity_3 [1, 63] FLOAT32` (world landmarks).

## 3. Enrolment, Matching & Emergency Safeguards

- **Feature vector (`lib/features/gestures/domain/hand_landmark_features.dart`):** Palm-centered (`mean(0, 5, 9, 13, 17)`), palm-scale-normalized 84-dim L2-unit vector (63 coords + 10 centered fingertip pairwise distances + 5 centered tip-to-wrist distances + 5 centered finger curl ratios + 1 palm spread).
- **Enrolment (`gesture_enrollment_engine.dart`):** Requires 5 samples with `handPresenceScore >= 0.65`, intra-gesture consistency `>= 0.84`, and max collision `< 0.90` against existing enrolled gestures.
- **Recognition (`gesture_recognition_engine.dart`):** Weighted score `0.6 * centroidSim + 0.4 * maxSampleSim`, threshold `>= 0.84`, top-2 ambiguity margin `>= 0.06`, sliding-window stability (`3/4` frames), and cooldown (`2000 ms` normal, `4000 ms` emergency).
- **Emergency gesture safeguard (`gesture_automation_bloc.dart`):** Mapping or firing `AssistiveActionId.startEmergencyAssistance` is blocked unless explicit `emergencyGestureOptIn == true`, and matching only opens the confirmation flow (never silent dialing).

## 4. Verification Classification

- **Implemented and verified:**
  - Live LiteRT `1.4.2` XNNPACK model load (`88 ms`), SHA-256 verification, and 224x224 RGB inference (`34 ms`) on Android 15 ARM64 emulator (`AssistiveControlsInstrumentedTest`).
  - Synthetic held-out landmark evaluation, enrolment rejection, temporal voting, cooldown, `TaskOrchestrator` routing, emergency opt-in gating, and `GestureAutomationScreen` widget test (`test/features/gestures/gesture_evaluation_test.dart`).
- **Implemented but not yet physically validated:** Live camera hand-pose accuracy across diverse skin tones, lighting, partial occlusion, and hand sizes on physical Android phones.
- **Partially implemented / Proposed:** Optional two-stage palm-ROI detector (`hand_detector.tflite`) for distant/small hands is **Proposed** for a future phase if physical-camera testing shows far-field recall drops.
- **Blocked:** Continuous background camera gesture listening is blocked by Android 14/15 background camera restrictions and Openetra privacy policy.
