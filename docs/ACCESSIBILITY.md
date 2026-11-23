# Accessibility Engineering Specification

## 1. Blind-First Interaction Model
Openetra is engineered for completely blind users operating with TalkBack enabled or voice-first control:
- **Large Primary Touch Targets:** Every primary workflow tile is `>= 64 dp` tall (`>= 80 dp` on home screen) with clear spacing to prevent mis-taps.
- **WCAG AAA High-Contrast Palette:** Deep black (`#000000`) background, crisp `#FFFFFF` primary text (> 21:1), `#FFD600` high-visibility caution/focus accent, `#FF5252` hazard critical alerts.
- **Complete TalkBack Semantics:**
  - Every control has descriptive `Semantics(button: true, label: ..., hint: ...)`.
  - Status & spoken output banners use `liveRegion: true` and `SemanticsService.announce`.
  - Logical vertical focus traversal order from top status -> voice/stop bar -> primary workflow tiles -> navigation drawer/settings.
- **Minimal Steps:** Workflows launch directly in 1 tap or 1 voice command.
- **Audio Interruption & Echo Prevention:** Single tap on the global **Stop / Interrupt Speech** bar cancels TTS cleanly; `isAssistantSpeaking` gates ASR capture so the app never listens to itself.
- **Distinct Haptic Vocabulary (`HapticsPlugin.kt`):**
  - `confirm`: single crisp pulse (`40 ms`)
  - `caution`: double short pulse
  - `warning`: triple firm pulse
  - `critical`: rapid urgent 4-pulse alarm pattern
  - `degraded`: slow long-short pattern
- **Accessible Onboarding:** Speaks safety scope clearly (not a white-cane replacement) and verifies offline TTS before proceeding.
