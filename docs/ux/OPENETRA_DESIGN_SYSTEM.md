# Openetra — Design System Specification

**Version:** 2.3.0  
**Source of Truth:** `lib/app/theme.dart`, `lib/shared/widgets/accessible_action_tile.dart`, `lib/shared/widgets/openetra_components.dart`

---

## 1. Brand Identity & Semantic Color Tokens (`OpenetraPalette`)

Openetra supports **Dark Aubergine** (default, calm low-glare) and **Warm White Light** (daylight high-contrast for low-vision users), plus **System Default**, persisted offline via `SettingsBloc` (`UpdateThemeMode`).

| Semantic Token | Dark (`OpenetraPalette.dark`) | Light (`OpenetraPalette.light`) | Usage |
|---|---|---|---|
| `background` | `#120B1A` Deep Aubergine | `#FFFDF9` Warm White | Primary scaffold canvas |
| `surface` | `#1E132B` Dark Plum | `#F4EEFB` Soft Lavender Tint | Cards, app bars, banners, inputs |
| `surfaceElevated` | `#2B1C3D` Layered Plum | `#FFFFFF` Pure Elevated Card | Action tiles, dialogs, pills |
| `textPrimary` | `#F8F5FF` Soft White (`>15:1`) | `#230A36` Deep Aubergine (`>15:1`) | Headings, primary body, labels |
| `textSecondary` | `#CEC4E0` Lavender-Grey (`>10:1`) | `#4B3661` Accessible Plum (`>8.8:1`) | Supporting text, subtitles |
| `primary` | `#C7A6FF` Refined Lavender | `#5D27B8` Deep Brand Violet (`>8.2:1`) | Focus indicators, active icons, links |
| `secondary` | `#FF9A3C` Warm Orange | `#C25700` Deep Warm Orange (`>4.9:1`) | Primary filled CTA, active accents |
| `onAccent` | `#120B1A` Deep Aubergine | `#FFFDF9` Warm White | Text/icon on primary/secondary fill |
| `border` | `#53416B` Plum Hairline | `#C4B3DC` Soft Plum Border | Card, tile, and input outlines |
| `success` | `#6FE3A8` Muted Green | `#126E42` Deep Green (`>6.1:1`) | Ready, verified, completed |
| `warning` | `#FFB84D` Warm Amber | `#9E5200` Deep Amber (`>5.5:1`) | Degraded notice, caution, exit armed |
| `error` | `#FF6B6B` Muted Red | `#B71C1C` Deep Red (`>6.4:1`) | Critical hazard, destructive actions |
| `info` | `#A5D8FF` Soft Sky | `#155A9C` Deep Blue (`>6.8:1`) | Informational badges |
| `disabled` | `#6D5E82` Muted Plum | `#8B7E9E` Muted Lilac | Disabled buttons & labels |

---

## 2. Typography Scale

All text styles inherit from `Theme.of(context).textTheme` so Android dynamic font scaling (up to `2.0x+`) and Indic scripts (`hi`, `kn`, `ta`, `te`, `ml`, `mr`, `bn`) render cleanly without clipping:

- `displaySmall`: 28sp · Bold (800) · `height: 1.2`
- `headlineMedium`: 24sp · Bold (700) · `height: 1.25`
- `titleLarge`: 20sp · Bold (700) · `height: 1.3` (Section headers)
- `titleMedium`: 18sp · SemiBold (600) · `height: 1.35` (Tile & card titles)
- `bodyLarge`: 17sp · Regular · `height: 1.45` (Spoken transcript & primary copy)
- `bodyMedium`: 15sp · Regular · `height: 1.45` (Supporting subtitles)
- `bodySmall`: 13sp · Regular · `height: 1.4` (Metadata & badges)
- `labelLarge`: 16sp · Bold (700) (Buttons & controls)
- `labelMedium`: 13sp · ExtraBold (800) · `letterSpacing: 0.7` (Status banners)

---

## 3. Spacing, Touch Targets & Motion Tokens

- **Spacing (`OpenetraSpacing`):** `xs=4`, `sm=8`, `md=12`, `lg=16`, `xl=20`, `xxl=28`.
- **Corner Radii:** `radiusSm=10`, `radiusMd=14`, `radiusLg=18`, `radiusPill=999`.
- **Touch Targets:** Minimum `48dp`, primary actions `68–76dp` (`AccessibleActionTile.minHeight = 76`).
- **Motion (`OpenetraMotion`):** `fast=140ms`, `normal=220ms`, `emphasized=300ms`, `pulse=1600ms`, `standardCurve=Curves.easeOutCubic`. `OpenetraMotion.resolve(context, target, reducedMotion: ...)` automatically collapses to `Duration.zero` when Android Reduce Animations or Openetra Reduced Motion is enabled.

---

## 4. Reusable Component Library

| Component | File | Accessibility Contract |
|---|---|---|
| `AccessibleActionTile` | `lib/shared/widgets/accessible_action_tile.dart` | `>=64–76dp` height, `Semantics(button: true, enabled, label, hint)`, `ExcludeSemantics` on decorative icon |
| `SpokenStatusBanner` | `lib/shared/widgets/accessible_action_tile.dart` | `Semantics(liveRegion: true)` immediate TalkBack announcement, color + icon + text status |
| `OpenetraSectionHeader` | `lib/shared/widgets/openetra_components.dart` | `Semantics(header: true)` landmark for TalkBack heading navigation |
| `OpenetraCard` | `lib/shared/widgets/openetra_components.dart` | Theme-aware bordered container |
| `OpenetraStatusBadge` | `lib/shared/widgets/openetra_components.dart` | Icon + label pill (never color-only) |
| `OpenetraEmptyState` | `lib/shared/widgets/openetra_components.dart` | Calm icon + title + clear next-step guidance |
| `OpenetraTextField` | `lib/shared/widgets/openetra_components.dart` | Inherits high-contrast `InputDecorationTheme` |
| `showOpenetraConfirmDialog` | `lib/shared/widgets/openetra_components.dart` | Accessible two-button confirmation dialog |
