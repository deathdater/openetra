# Gesture Model Evaluation Report

**Product:** Openetra  
**Model:** `assets/models/gesture/hand_landmarks_detector.tflite` (extracted from official Apache-2.0 MediaPipe `hand_landmarker/float16/1/hand_landmarker.task`)  
**Runtime:** Bundled `com.google.ai.edge.litert:litert:1.4.2` (XNNPACK, 2 threads, zero new Gradle dependencies)

---

## 1. Model Asset & Tensor Verification

- **File size:** `5,478,949` bytes (`~5.23 MB`)
- **SHA-256:** `6acda74af3fbf40e68265c20c7394b2bad81a16a481dcd79ad7a081887c3d6b9`
- **Licence:** Apache-2.0
- **Input tensor:** `input_1` `[1, 224, 224, 3]` `FLOAT32` RGB `[0..1]`
- **Output tensors:** `Identity [1, 63]` (21x3 landmarks), `Identity_1 [1, 1]` (hand presence), `Identity_2 [1, 1]` (handedness), `Identity_3 [1, 63]` (world landmarks)

## 2. Live On-Device Runtime Verification (Android 15 ARM64 Emulator)

Executed via `AssistiveControlsInstrumentedTest.handGestureModelVerifiesSha256AndRunsLiveLiteRtInference` on `Medium_Phone_API_35` (`arm64-v8a`, Android 15):
- **SHA-256 integrity check:** Passed (`6acda74af3fbf40e68265c20c7394b2bad81a16a481dcd79ad7a081887c3d6b9`)
- **Cold asset copy + LiteRT XNNPACK load:** `88 ms`
- **Single-frame 224x224 RGB inference:** `34 ms`
- **Synthetic non-hand noise frame `handPresenceScore`:** `0.0013` (cleanly below `0.65` rejection threshold)

## 3. Synthetic Held-Out Classifier Evaluation (Host Test Suite)

Executed via `test/features/gestures/gesture_evaluation_test.dart` using palm-centered 84-dim L2-unit descriptors (`HandLandmarkFeatureExtractor`) across 5 enrolled classes (`open_palm`, `peace_v`, `closed_fist`, `index_point`, `thumbs_up`; 5 training samples each) evaluated on 100 held-out perturbed positive samples (random translation, scale `0.15..0.37`, landmark jitter `±0.025`) and 60 unseen negative/unknown poses (`horns`, `shaka`, `three_fingers`):

| Metric | Observed Result (Synthetic Held-Out) | Target |
|---|---|---|
| True Positives | `100 / 100` | `>= 95 / 100` |
| False Positives (Known + Unknown) | `0` | `<= 3` |
| False Negatives | `0` | `<= 5` |
| Precision | `100.0%` | `>= 95.0%` |
| Recall | `100.0%` | `>= 95.0%` |
| Unknown Pose Rejection Rate (`60` unseen poses) | `100.0%` | `>= 95.0%` |
| FAR / FRR | `0.0%` / `0.0%` | `<= 5.0%` |

## 4. Honest Limitations & Verification Classification

- **Implemented and verified:** Model SHA-256, LiteRT `1.4.2` XNNPACK load (`88 ms`) and inference (`34 ms`) on Android 15 ARM64 emulator, and synthetic held-out geometric classifier accuracy (`100%` precision/recall/unknown rejection).
- **Implemented but not yet physically validated:** Real-world physical-camera hand-pose evaluation across multiple human subjects, varied illumination, motion blur, skin tones, and distant hands (without a separate palm ROI cropper).
- **Proposed:** Add optional two-stage `hand_detector.tflite` palm ROI detector in a future phase if physical-camera trials show far-field landmark degradation.
