# Background Task Orchestration

**Product:** Openetra  
**Core Package:** `lib/core/assistive/`

---

## 1. Unified Execution Pipeline

All four input modalities (in-app buttons, offline voice, custom hand gestures, and floating companion orb) route through a single pipeline without duplicating domain services:

```
User Input (UI / Voice / Gesture / Floating Orb)
  -> AssistiveActionRouter (canonical AssistiveActionId + metadata spec)
  -> CapabilityAvailabilityService (foreground/background + permission check)
  -> TaskOrchestrator (taskId, duplicate-tap debounce, timeout, preemption, cancellation)
  -> Existing Openetra Domain Workflows (Coordinator / BLoCs / Flashlight / Emergency)
  -> FeedbackDispatcher (sanitized AssistiveTaskSnapshot -> AudioBloc + FloatingOverlayStateSink)
```

## 2. Execution Categories (`BackgroundExecutionCategory`)

| Category | Meaning | Examples | Behavior from Background |
|---|---|---|---|
| **Category A** (`backgroundSafe`) | No live camera/mic capture required | `toggleFlashlight`, `cancelActiveTask`, `repeatLast` | Permitted directly via bridge |
| **Category B** (`foregroundServicePermitted`) | Explicit user-started `specialUse` FGS | Floating orb hosting | Persistent non-sensitive notification required |
| **Category C** (`foregroundUiRequired`) | Requires camera, microphone, or explicit user confirmation UI | `describeScene`, `readText`, `assessHazardCues`, `identifyCurrency`, `scanProduct`, `findRegisteredObject`, `startEmergencyAssistance` | Blocked if `fromBackground == true`; `FloatingCompanionService` launches `MainActivity` (`EXTRA_ASSISTIVE_ACTION`) so execution happens transparently in foreground |

## 3. State Publishing & Privacy Sanitization

`FeedbackDispatcher` subscribes to `TaskOrchestrator.snapshots` and forwards only sanitized phase metadata (`AssistiveTaskPhase` + short generic status label) to `FloatingOverlayStateSink` (`NativeFloatingCompanionBridge`). Sensitive OCR text, scene captions, and contact phone numbers are never placed into persistent notifications or overlay state payloads.

## 4. Verification Classification

- **Implemented and verified:** Duplicate-tap debouncing, timeout handling, emergency preemption, explicit cancellation, Category A vs C gating, and `FeedbackDispatcher` sanitization (`test/core/assistive/shared_architecture_test.dart`, `test/features/floating_companion/floating_companion_test.dart`).
- **Implemented but not yet physically validated:** End-to-end background-to-foreground `MainActivity` trampoline timing under OEM background process limits.
- **Partially implemented / Proposed / Blocked:** None.
