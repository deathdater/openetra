# Openetra — Assistive Dial Interaction Specification

**Source of Truth:** `lib/features/dial/models/dial_menu_node.dart`, `lib/features/dial/bloc/assistive_dial_bloc.dart`, `lib/features/dial/domain/dial_gesture_recognizer.dart`, `lib/features/dial/presentation/widgets/assistive_dial.dart`, `dial_center.dart`, `dial_focus_glyph.dart`

## 1. Interaction Model
- **Browse (`Horizontal Swipe` or `Previous` / `Next` >=64dp buttons):** Moves focus across options, speaks concise option title/purpose via `AudioArbitrator.announceSelection` (zero-backlog), and fires light selection haptic.
- **Select / Enter (`Slide Up` or `Select` / `Confirm` >=64dp button):** Enters submenu, routes to dedicated screen, or executes selected action with confirmation haptic.
- **Return / Cancel / Exit (`Slide Down` or `Back` / `Cancel` / `Exit` >=64dp button):** Cancels active operation, returns to parent menu, or arms two-step root exit (5-second window with warning haptic).
- **Repeat (`Repeat` >=64dp button):** Re-announces current option and menu position.

## 2. State Machine & Ring Feedback (`DialCenter.ringColorForPhase`)
| Phase | Semantic Token (`OpenetraPalette`) | Motion |
|---|---|---|
| `initializing`, `ready`, `rootMenu`, `submenu`, `paused` | `palette.primary` | Static (zero idle GPU animation) |
| `confirmingAction`, `exitArmed` | `palette.warning` | Gentle pulse (if motion enabled) |
| `executing`, `listening`, `processing`, `speaking` | `palette.secondary` | Gentle pulse + waveform crest |
| `completed` | `palette.success` | Static |
| `failed` | `palette.error` | Static |

## 3. Theme & Reduced-Motion Compliance
- `DialCenter`, `DialFocusGlyph` (20 bespoke vector emblems), and `_RadialMarkersPainter` resolve all colors dynamically via `OpenetraTheme.paletteOf(context)` across **Dark Aubergine** and **Warm White Light** themes.
- `OpenetraMotion.resolve(context, ..., reducedMotion: ...)` collapses all transitions to `Duration.zero` when Android Reduce Animations or Openetra Reduced Motion is active.
