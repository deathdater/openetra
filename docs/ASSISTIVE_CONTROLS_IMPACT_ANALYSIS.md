# Openetra Assistive Controls & Floating Companion — Repository Impact Analysis

**Version:** `1.1.0-assistive-phase0-1` (baseline verified against `3086909` / `v1.0.0-release-candidate`)  
**Scope:** Emergency Assistance, Intelligent Flashlight, Custom Hand Gesture Automation, Floating Assistive Widget, and Policy-Compliant Background Task Orchestration.

---

## 1. Baseline Toolchain & Verification Status
- **Flutter SDK:** `3.22.3` (`Dart 3.4.4`, `sdk: '>=3.4.0 <4.0.0'` in `pubspec.yaml`).
- **Android Build Chain:** Android Gradle Plugin `8.5.2`, Kotlin `2.2.20`, Gradle `8.7` (`android/settings.gradle`), OpenJDK `21.0.10`, NDK `27.0.12077973`, CMake `3.22.1`.
- **Android SDK Targets (`android/app/build.gradle`):** `compileSdk = 36`, `targetSdk = 35`, `minSdk = 26`, ABI filters `arm64-v8a`, `armeabi-v7a`.
- **Baseline Pre-Change Checks (Verified):**
  - `flutter analyze`: `No issues found!`.
  - `flutter test -r expanded`: `40/40` host unit and widget tests passing.
  - Physical hardware battery, camera/torch contention, overlay, dialer, and TalkBack field verification: **Not yet verified** (scheduled on real devices after Android 15 `arm64-v8a` emulator checks).

---

## 2. Existing Reusable Architecture & Component Map

| Existing Component | Verified File Location | Role / Reusability |
|---|---|---|
| Dependency Composition Root | `lib/app/app.dart` (`OpenetraDependencies.bootstrap`) | Wires SQLite, resource manager, Mirage/Indic/specialist providers, 11 BLoCs, `AudioBloc`, `SafetyBloc`, and `OpenetraCoordinator`. Reused as the single composition graph. |
| Workflow Coordinator | `lib/app/openetra_coordinator.dart` (`OpenetraCoordinator`) | Orchestrates Workflows A–E (`runDescribeSurroundings`, `runHazardScan`, `runSmartReader`, `runIdentifyCurrency`, `runFindObject`, `runScanProduct`, `listenForOfflineVoiceCommand`, `stopAll`, `registerPersonalObjectWithCamera`). Extended through shared action router rather than duplicated. |
| Android Main Activity & Plugins | `android/app/src/main/kotlin/com/openetra/app/MainActivity.kt` | Registers `MirageEnginePlugin`, `CameraXCaptureManager`, `DeviceResourcePlugin`, `HapticsPlugin`, `IndicOcrPlugin`, `OfflineSpeechPlugin`, `SpecialistVisionPlugin`. Extended with `EmergencyAssistancePlugin`, `FlashlightPlugin`, `HandGesturePlugin`, `FloatingCompanionPlugin`. |
| Camera Capture & Pitch | `android/app/src/main/kotlin/com/openetra/app/camera/CameraXCaptureManager.kt` + `lib/core/camera/camera_controller_bridge.dart` | Single CameraX `ImageAnalysis` (`640x480`, `STRATEGY_KEEP_ONLY_LATEST`, `YUV_420_888 -> RGB24`), C++ quality metrics (`meanLuma`, `laplacianVariance`, exposure ratios), accelerometer pitch. Extended to retain bound `Camera` for CameraX torch control and single-owner leasing via `CameraResourceManager`. |
| AI Orchestrator & Model Registry | `lib/core/inference/ai_model_orchestrator.dart` & `ai_model_registry.dart` | Serialized single-flight native AI invocation (`_runSerialized`), thermal critical blocking (`ThermalThrottleFailure`), lazy load/unload, SHA-256 verification. |
| Audio & TalkBack Stack | `lib/core/audio/speech_controller.dart`, `accessibility_announcer.dart`, `bloc/audio_bloc.dart` | Single offline `flutter_tts` + `HapticsPlugin` pipeline with `shouldGateMicrophone` (`350 ms` echo tail). Wrapped by `AudioArbitrator` rather than adding a second TTS instance. |
| Telemetry & Offline Voices | `android/.../resources/DeviceResourcePlugin.kt` & `lib/core/resource_management/device_resource_manager.dart` | Reads battery%, charging, API 29+ `PowerManager.currentThermalStatus`, RAM, and offline `TextToSpeech.getVoices()`. |
| Offline SQLite Persistence | `lib/core/storage/openetra_database.dart` (`schemaVersion = 2`) | 11 tables including `local_products`; upgraded to `schemaVersion = 3` for `assistive_preferences` and `custom_gestures`. Trusted emergency contacts are **not** stored plaintext in SQLite — encrypted separately with Android Keystore AES-256-GCM. |
| Manifest Network Policy | `android/app/src/main/AndroidManifest.xml` & `android/app/src/release/AndroidManifest.xml` | Production/release manifest strips `INTERNET` and `ACCESS_NETWORK_STATE` via `tools:node="remove"`. Must remain zero-network across all new components. |

---

## 3. Architectural Gaps Identified
1. **No Unified Action Registry or Task State Machine:** `OpenetraCoordinator` exposes separate methods with boolean `_hazardLoopActive` tracking only; there is no broadcast `AssistiveTaskPhase` state stream for in-app + overlay synchronization, duplicate-tap debounce, cancellation tokens, or emergency preemption.
2. **No Camera Lease Arbitration:** `CameraControllerBridge` calls `start`/`captureFrame`/`stop` directly. Without `CameraResourceManager`, a new feature (gesture recognition or luminance measurement) could race or starve active workflows.
3. **Torch & Light-Sensor Gap:** `CameraXCaptureManager.startCamera` calls `provider.bindToLifecycle(...)` without storing the returned `Camera` instance (`camera.cameraControl.enableTorch(...)`), and no ambient light (`Sensor.TYPE_LIGHT`) or `CameraManager.TorchCallback` ownership tracker exists.
4. **Secure Contact Storage & Dialer Bridge Missing:** No Android Keystore AES-GCM store or `Intent.ACTION_DIAL` launcher exists yet.
5. **No Gesture Feature/Enrolment Pipeline:** Lightweight offline hand-landmark inference and local template matching are absent.
6. **No Cross-App Overlay or Android 14/15 `specialUse` Foreground Service:** `AndroidManifest.xml` currently declares only `CAMERA`, `RECORD_AUDIO`, `VIBRATE`.

---

## 4. Android API, Permission, Lifecycle & Dependency Review
- **Zero New Third-Party Dependencies Needed:**
  - **Emergency Storage & Dialer:** Android Framework Keystore (`AES/GCM/NoPadding`), `Intent.ACTION_DIAL` (requires no `CALL_PHONE` permission and puts confirmation cleanly in user control).
  - **Intelligent Flashlight:** Android `CameraManager.TorchCallback` + `Sensor.TYPE_LIGHT` + `CameraX` `Camera.cameraControl.enableTorch` (zero new dependencies).
  - **Custom Hand Gesture Landmark Extractor:** Reuse already-bundled Apache-2.0 **LiteRT `1.4.2` (`org.tensorflow.lite.Interpreter` + XNNPACK)** paired with official Apache-2.0 MediaPipe `hand_landmarks_detector.tflite` extracted from `hand_landmarker.task` (`hand_landmarker` float16 v1). Avoids duplicate TFLite symbol collisions between `litert:1.4.2` and `com.google.mediapipe:tasks-vision`.
  - **Floating Companion Overlay:** Native Android `WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY` (API 26+) + `FOREGROUND_SERVICE_SPECIAL_USE` (`android:foregroundServiceType="specialUse"` + `<property android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE" .../>` required by Android 14/15 `targetSdk 35`) + `POST_NOTIFICATIONS` (API 33+).
- **Background Execution Policy (Category A / B / C):** On Android 14/15, starting camera (`foregroundServiceType="camera"`) or microphone (`microphone`) from background without a qualifying active UI/exempt state throws `ForegroundServiceStartNotAllowedException`. Openetra therefore enforces Category C rules honestly: triggering camera/mic actions from the floating orb when Openetra is backgrounded brings `MainActivity` to foreground via an explicit `Intent` action rather than covert background capture.

---

## 5. Regression Risks & Mitigation
1. **Breaking First-6-Tile Widget Tests (`HomeScreen`):** Tests assert the first 6 core buttons on a `1080x2400` viewport. All new UI controls go into sub-screens (`Emergency`, `Flashlight`, `Gestures`, `Floating Companion`) or below existing primary action tiles.
2. **Release R8 / ProGuard Stripping & Network Permissions:** `src/release/AndroidManifest.xml` must continue removing `INTERNET` and `ACCESS_NETWORK_STATE`; new native plugins & services must be covered in `android/app/proguard-rules.pro`.
3. **TalkBack Conflict on Floating Orb:** The overlay orb sets `contentDescription` dynamically per state, avoids strobing, pauses all animations in `IDLE`/`PAUSED` or reduced-motion mode, and never acts as the sole path for any critical or emergency function.

---

## 6. Recommended Phased Sequence & Decisions Made
- **Decision — Default Dialer Handoff (`ACTION_DIAL`):** Chosen over `CALL_PHONE` as default to eliminate accidental calls and zero extra dangerous permission surface.
- **Decision — LiteRT `1.4.2` for Hand Landmarks:** Chosen over adding `tasks-vision` to preserve APK footprint, keep Apache-2.0 cleanliness, and guarantee zero JNI/dex collisions.
- **Phased Execution Order:**
  1. **Phase 0–1 (`v1.1.0`):** Shared `lib/core/assistive/` layer + SQLite `v3` (`assistive_preferences`, `custom_gestures`).
  2. **Phase 2–4 (`v1.2.0`):** Emergency Assistance + Intelligent Flashlight (manual + hysteresis auto mode).
  3. **Phase 5–7 & 10 (`v1.3.0`):** Hand Gesture evaluation (`hand_landmarks_detector.tflite`), enrolment, matching, and emergency gesture safeguards.
  4. **Phase 8–9 (`v1.4.0`):** Floating Assistive Widget (`WindowManager` + `specialUse` FGS) & policy-compliant background orchestration.
  5. **Phase 11 (`v1.5.0`):** Android 15 emulator instrumentation (`AssistiveControlsInstrumentedTest`), zero-network `app-release.apk` verification, all 15 docs, and physical-device test checklist.
