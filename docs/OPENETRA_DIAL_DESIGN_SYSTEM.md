# Openetra Assistive Dial — Visual Design System (Phase 3)

## 1. Brand Identity & Colour Palette (`OpenetraTheme`)

Preserves Openetra's calm, trustworthy **Deep Aubergine + Dark Plum + Refined Lavender + Warm Orange** direction and simple open-circle / waveform / orange-accent brand mark while maintaining **WCAG AAA (>= 7:1)** text contrast.

| Token | Hex | Role |
|---|---|---|
| `background` | `#120B1A` | Primary Deep Aubergine canvas |
| `surface` | `#1E132B` | Dark Plum elevated surface |
| `surfaceElevated` | `#2B1C3D` | Layered dial ring / tile surface |
| `accentLavender` | `#C7A6FF` | Primary Refined Lavender accent & active marker |
| `accent` (Warm Orange) | `#FF9A3C` | Secondary Warm Orange accent, active selection glow, brand dot |
| `accentText` | `#120B1A` | High-contrast dark ink on lavender/orange fills |
| `primaryText` | `#F8F5FF` | Soft White primary typography (>15:1 contrast on `#120B1A`) |
| `secondaryText` | `#CEC4E0` | Muted Lavender-Grey secondary copy (>10:1 contrast) |
| `okGreen` | `#6FE3A8` | Accessible muted green (completed/ready) |
| `hazardWarning` | `#FFB84D` | Warm amber (caution / exit armed) |
| `hazardCritical` | `#FF6B6B` | Accessible muted red (error / emergency) |
| `border` | `#53416B` | Subtle plum-lavender hairline border |

## 2. Typography & Scaling

- Uses system sans-serif with full Devanagari / Kannada / Tamil / Telugu / Malayalam / Bengali glyph coverage.
- Dynamic text scaling supported cleanly without fixed-height text clipping (`MediaQuery.textScalerOf(context)` respected).
- Hierarchy: Active option title (`24 sp`, bold), Purpose description (`16 sp`, `1.4` line height), Menu breadcrumb (`14 sp`, uppercase tracked), Directional cue labels (`14 sp`).

## 3. Radial Dial Geometry & Layered Depth

- **Outer ambient ring:** Soft radial glow tinted by current `DialLifecyclePhase` (Lavender in browsing, Warm Orange on selection/activation, Cyan-Lavender during listening/processing, Muted Green on completion, Muted Red in emergency flow).
- **Option marker ring:** Evenly spaced radial ticks/dots representing only the current menu level (<= 8 at root, <= 4 in submenus). Active option marker expands into a warm-orange capsule with subtle halo.
- **Central identity disc (`DialCenter`):** Layered Dark Plum disc containing Openetra's custom-painted **open-circle + calm waveform + warm-orange accent dot** logo mark, morphing into a restrained waveform during listening/speaking or gentle breathing ring during processing.
- **Zero idle animation:** When `phase` is `rootMenu` / `submenu` / `ready` / `paused` / `completed` or when `reducedMotion == true` (`MediaQuery.disableAnimationsOf(context)` or user preference), continuous animations stop completely (`RepaintBoundary` isolates dial repaints).
