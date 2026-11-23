# Assistive Controls Accessibility Specification

**Product:** Openetra  
**Primary Users:** Completely blind and low-vision Android users operating with TalkBack and voice-first navigation

---

## 1. Non-Negotiable Accessibility Commitments

- **Touch targets & contrast:** Every interactive control across `EmergencyAssistanceScreen`, `EmergencyContactsScreen`, `FlashlightSettingsScreen`, `GestureAutomationScreen`, and `FloatingWidgetSettingsScreen` reuses `AccessibleActionTile` (`>= 64 dp` height, high-contrast dark theme `OpenetraTheme`).
- **HomeScreen preservation:** The top 6 primary action tiles on `HomeScreen` remain untouched above the fold; existing accessibility regression tests (`test/accessibility/voice_first_accessibility_widget_test.dart`) continue passing unmodified.
- **TalkBack semantics on floating orb (`FloatingOrbView.kt`):**
  - `importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_YES`
  - Dynamic `contentDescription` reflects all 10 task phases (`Idle`, `Listening`, `Processing`, `Analyzing visually`, `Speaking response`, `Emergency confirmation active`, etc.)
  - Explicit `ACTION_CLICK` ("Run primary assistive action") and `ACTION_LONG_CLICK` ("Trigger secondary or emergency confirmation action") labels.
- **Reduced motion:** `FloatingOrbView` runs zero `ValueAnimator` in `IDLE`, `PAUSED`, `COMPLETED`, when `reducedMotionOverride == true`, or when `Settings.Global.ANIMATOR_DURATION_SCALE == 0f`.
- **Audio arbitration (`AudioArbitrator`):** Deduplicates rapid status announcements (cooldown window), prioritizes emergency prompts (`speakPriorityEmergency`), and avoids overlapping TTS clutter.
- **Voice commands (`VoiceIntentRouter`):** Offline English and Hindi phrases (`emergency`, `आपातकाल`, `flashlight`, `टॉर्च`) route directly to Emergency Assistance and Flashlight controls.

## 2. Verification Classification

- **Implemented and verified:** Widget tests for all 4 new screens, `HomeScreen` >=64dp touch targets & TalkBack semantics, and `FloatingOrbView` `contentDescription` + reduced-motion checks on Android 15 ARM64 emulator (`AssistiveControlsInstrumentedTest`).
- **Implemented but not yet physically validated:** Live TalkBack swipe-order, earcon timing, and blind-user usability testing on physical Android devices.
- **Partially implemented / Proposed / Blocked:** None.
