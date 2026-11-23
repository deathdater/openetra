# Openetra — Accessibility Specification & Test Plan

## 1. System-Wide Accessibility Contract
- **WCAG Contrast Verified Automatically (`test/ui/design_system_and_a11y_test.dart`):**
  - Body text (`textPrimary` & `textSecondary` on `background`, `surface`, `surfaceElevated`): **`>= 7.0:1` (WCAG AAA)** in both Dark Aubergine and Warm White Light themes.
  - Accent buttons (`onAccent` on `primary` and `secondary`): **`>= 4.5:1`** (Dark `#FF9A3C` / `#120B1A`, Light `#B84F00` / `#FFFDF9` `>5.0:1`).
- **Touch Targets:** Minimum `48dp` (`OpenetraSpacing.minTouchTarget`); all primary action tiles and dial alternative controls `>= 64–76dp`.
- **TalkBack Landmarks:** `OpenetraSectionHeader` (`Semantics(header: true)`) added across screens including `EmergencyAssistanceScreen` and `FloatingWidgetSettingsScreen`; decorative icons wrapped in `ExcludeSemantics`.
- **Dynamic Text Scaling:** Verified at `2.0x` linear `TextScaler` on `AssistiveDialPage` in both Dark and Light themes with zero layout overflow exceptions.
- **Reduced Motion:** `OpenetraMotion.resolve(...)` and `DialCenter._reconcileAnimation()` honor both `MediaQuery.disableAnimationsOf(context)` and Openetra's in-app `reducedMotion` setting; idle dial never animates.

## 2. Manual Android / TalkBack Verification Checklist
1. Enable TalkBack -> verify reading order on `OnboardingScreen`, `AssistiveDialPage`, `SettingsScreen`, `SceneMemoryScreen`, and `EmergencyAssistanceScreen`.
2. Toggle **Warm White Light** and **Dark Aubergine** in `Settings -> Appearance & Theme` -> verify persistence across cold app restart.
3. Set Android Display Size & Font Size to Largest -> verify zero text clipping across all screens.
4. Enable Android **Remove Animations** -> verify dial pulse and transitions immediately become instantaneous.
