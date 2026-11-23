# Openetra — UI/UX & Accessibility Transformation Release Notes (`v2.3.0`)

**Date:** 2026-11-23  
**Tag:** `v2.3.0-premium-ux-and-a11y-transformation`

## Highlights
- **Dual WCAG AAA Theme System (Dark Aubergine & Warm White Light):** Added `OpenetraPalette` (`ThemeExtension`), `OpenetraSpacing`, `OpenetraMotion`, full 9-slot scalable typography, and offline `ThemeMode` persistence (`Dark Aubergine`, `Warm White Light`, `System`) via `SettingsBloc`.
- **Shared Accessible Component Library:** Added `OpenetraSectionHeader`, `OpenetraCard`, `OpenetraStatusBadge`, `OpenetraEmptyState`, `OpenetraTextField`, and `showOpenetraConfirmDialog` while upgrading `AccessibleActionTile` and `SpokenStatusBanner` to semantic tokens.
- **Zero Hardcoded Colors Across All 13 Screens & Assistive Dial:** Eliminated all **134** hardcoded static `OpenetraTheme.*` calls across `lib/features/` and `lib/shared/`. `AssistiveDial`, `DialCenter`, and all 20 `DialFocusGlyph` emblems now adapt seamlessly between Dark and Light themes.
- **Streamlined Settings & Landmarks:** Added `Appearance & Theme` chips, converted the 8-language wall into a calm expandable selector, and added missing `Semantics(header: true)` landmarks on `EmergencyAssistanceScreen` and `FloatingWidgetSettingsScreen`.
- **Zero Regressions:** All `75/75` automated host tests pass (`71` baseline + `4` new WCAG contrast, `2.0x` text scale, theme persistence, and reduced-motion tests), `flutter analyze` reports `0` issues, and `0` new dependencies were added.
