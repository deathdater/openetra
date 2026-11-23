# Openetra — Screen Specifications & UI Architecture

**Source of Truth:** `lib/app/app.dart`, `lib/app/theme.dart`, `lib/shared/widgets/`

## 1. Architecture Summary
- **State Management:** Existing `flutter_bloc` architecture preserved (15 BLoCs). `SettingsBloc` now also persists `ThemeMode` (`dark`, `light`, `system`) in SQLite `assistive_preferences` (`ui_theme_mode`) — zero schema migration required.
- **Design System Injection:** `OpenetraApp` wraps `MaterialApp` with `BlocBuilder<SettingsBloc, SettingsState>(buildWhen: (p, c) => p.themeMode != c.themeMode)` supplying `OpenetraTheme.buildLightTheme()` and `OpenetraTheme.buildDarkTheme()`.
- **Zero Hardcoded Colors:** Reduced hardcoded `OpenetraTheme.*` static color calls in UI from **134** to **0** across all 13 screens, 3 dial widgets, and shared components.

## 2. Screen-by-Screen Contracts
- **AssistiveDialPage:** Primary voice-first command center with `Offline Ready` & active language `OpenetraStatusBadge`s, live-region `SpokenStatusBanner`, theme-aware `AssistiveDial`, and direct `Classic List View` + `Settings` app bar actions.
- **OnboardingScreen:** Restrained Openetra iris emblem (`DialFocusGlyph`), offline & TalkBack badges, honest safety notice, voice test button, and primary CTA.
- **HomeScreen (Classic List View):** Parity vertical list with structured `OpenetraStatusBadge` pills (Mode, Language, Battery), `OpenetraTextField` offline command bar, and >=64dp action tiles.
- **SettingsScreen:** Organized into semantic sections (`Appearance & Theme` 3-way selector, collapsible `Voice & Language` picker + speed slider, `Power & Operating Mode`, `Continuous Scene Understanding`, assistive controls links, `Dial Interaction, Haptics & Motion`, and `Privacy & Data` with `showOpenetraConfirmDialog`).
- **SceneMemoryScreen, ObjectMemoryScreen, EmergencyAssistanceScreen, EmergencyContactsScreen, FloatingWidgetSettingsScreen, GestureAutomationScreen, ModelManagerScreen, ShoppingScreen, FlashlightSettingsScreen:** All use `OpenetraPalette`, `OpenetraSectionHeader`, `OpenetraCard`, `OpenetraEmptyState`, and `OpenetraTextField` consistently.
