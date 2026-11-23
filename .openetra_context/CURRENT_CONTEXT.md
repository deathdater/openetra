# Openetra Local Engineering Context

**Current Version:** `1.4.0-floating-companion`  
**Phase:** Assistive Controls Milestone 4 (Phases 8–9) — Floating Assistive Companion & Background Orchestration  
**Last Updated:** 2026-11-23  
**Git Branch:** `main`  

## Delivered in `v1.4.0-floating-companion`
- **Android Native Overlay & Service:** Added `FloatingWidgetState.kt` (10 states matching `AssistiveTaskPhase`), `FloatingOrbView.kt` (high-contrast calm radial glow, zero animator in `IDLE`/`PAUSED`/`COMPLETED` or reduced-motion, TalkBack semantics, snap-to-edge + inset clamping), `FloatingCompanionService.kt` (Android 14/15 `specialUse` foreground service with `PROPERTY_SPECIAL_USE_FGS_SUBTYPE`, honest non-sensitive notification with Hide & Stop action, Category A vs Category C `MainActivity` trampoline), and `FloatingCompanionPlugin.kt` (`com.openetra.app/floating_companion`).
- **Flutter Integration:** Implemented `FloatingWidgetConfig`, `FloatingCompanionBridge` (`FloatingOverlayStateSink`), `FloatingCompanionBloc`, and `FloatingWidgetSettingsScreen`; attached `FeedbackDispatcher.attachOverlaySink(floatingBridge)` and wired Settings & `MainActivity.onNewIntent`.
- **Verification:** `flutter analyze` (`No issues found!`) and `flutter test -r expanded` (`58/58` passing).
