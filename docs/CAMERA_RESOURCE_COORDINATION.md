# Camera Resource Coordination

**Product:** Openetra  
**Core Components:** `lib/core/assistive/camera_resource_manager.dart`, `android/app/src/main/kotlin/com/openetra/app/camera/CameraXCaptureManager.kt`, `android/app/src/main/kotlin/com/openetra/app/flashlight/FlashlightPlugin.kt`

---

## 1. Single-Owner Camera Guarantee

Openetra never opens parallel CameraX or Camera2 sessions across Scene Understanding, Smart Reader, Hazard Detection, Object Search, Shopping, Custom Hand Gestures, or Intelligent Flashlight:

- **Logical lease arbitration (`CameraResourceManager`):** All camera workflows acquire a typed `CameraLease` (`CameraLeasePurpose.scene`, `hazard`, `reader`, `currency`, `objectSearch`, `shopping`, `gestureSession`). Concurrent acquisition without `preemptExisting: true` throws a clear `StateError`; user-initiated preemption cleanly calls `stop()` before re-acquiring.
- **Shared luminance fan-out (`ActiveFrameLumaListener`):** Every `captureFrame(lease)` publishes `frame.qualityMetrics.meanLuma` to subscribed listeners (including `IntelligentFlashlightController`), enabling low-light auto-torch fallback with zero extra camera sessions (`startCount == 1`).
- **Unified torch routing (`FlashlightPlugin` + `CameraXCaptureManager`):** When `CameraXCaptureManager.isCameraActive()` is `true`, torch toggles route through `boundCamera.cameraControl.enableTorch(enabled)` rather than calling `CameraManager.setTorchMode` (which fails with `CAMERA_IN_USE` while CameraX owns the sensor). When the camera is closed, `FlashlightPlugin` uses `CameraManager.setTorchMode` while honoring `TorchCallback` external ownership.

## 2. Verification Classification

- **Implemented and verified:** Single-owner lease contention, preemption, active-frame `meanLuma` sharing (`startCount == 1`), and release cleanup (`test/core/assistive/shared_architecture_test.dart`, `test/features/flashlight/intelligent_flashlight_test.dart`).
- **Implemented but not yet physically validated:** Real CameraX + LED torch switching under rapid user task preemption on physical Android hardware.
- **Partially implemented / Proposed / Blocked:** None.
