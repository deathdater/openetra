# Floating Assistive Widget — Product Specification

**Product:** Openetra  
**Status Summary:** Optional overlay orb, 10-state calm glow, TalkBack semantics, reduced-motion controls, and settings UI implemented and verified via host + Android 15 emulator tests; multi-app OEM overlay ergonomics and live TalkBack drag/reposition remain **Implemented but not yet physically validated**.

---

## 1. User Experience & Accessibility Goals

Provides an optional, persistent, high-contrast floating button above other Android apps so blind and low-vision users can trigger Openetra actions without searching for the app icon.

- **Opt-in only:** Disabled by default. Enabling requires explicit user grant of Android's `SYSTEM_ALERT_WINDOW` ("Display over other apps") permission via system settings.
- **Honest task-state glow:** Mirrors genuine `AssistiveTaskPhase` transitions published by `FeedbackDispatcher` (`idle`, `activated`, `listening`, `processing`, `aiInference`, `speaking`, `completed`, `failed`, `paused`, `emergencyFlow`).
- **Calm visual design & battery discipline:** Zero animation runs in `idle`, `paused`, or `completed` states, or whenever `reducedMotionOverride` or Android's `ANIMATOR_DURATION_SCALE == 0` is active.
- **Full TalkBack compatibility:** Exposes dynamic `contentDescription` announcing the current task phase plus explicit `ACTION_CLICK` and `ACTION_LONG_CLICK` node labels.
- **Configurable interactions:** Single tap (primary action), double tap (secondary/cancel action), long press (configurable, default emergency confirmation), orb size (`48–96 dp`), and snap-to-edge repositioning with safe screen-margin clamping.

## 2. Persistent Notification Transparency

While active, `FloatingCompanionService` displays a persistent, low-priority, **non-sensitive** notification ("Openetra Companion Active") containing no OCR text, scene captions, or contact details, with an immediate **Hide & Stop** action.

## 3. Verification Classification

- **Implemented and verified:** 10-state mapping, zero idle/paused/reduced-motion animation, TalkBack `contentDescription` updates (`AssistiveControlsInstrumentedTest`), permission-revocation auto-shutdown, `FeedbackDispatcher` state forwarding, and `FloatingWidgetSettingsScreen` (`test/features/floating_companion/floating_companion_test.dart`).
- **Implemented but not yet physically validated:** Real TalkBack touch-exploration over third-party apps, OEM battery-optimization behavior (Samsung/Xiaomi/OnePlus), and physical display-cutout / rotation ergonomics.
- **Partially implemented / Proposed / Blocked:** None.
