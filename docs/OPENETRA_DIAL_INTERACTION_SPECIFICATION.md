# Openetra Assistive Dial — Interaction Specification (Phase 2)

## 1. Core Rhythm

`Explore -> Hear -> Feel -> Select -> Understand -> Act -> Return`

- **Single source of truth:** `AssistiveDialBloc` owns the focused option index, menu stack, operation phase, confirmation state, and root-exit armed state. Voice, haptics, and visuals all subscribe to the same emitted `AssistiveDialState`.

## 2. Deterministic State Machine (`DialLifecyclePhase`)

| Phase | Entry Trigger | Permitted Transitions |
|---|---|---|
| `initializing` | App launch | `ready` |
| `ready` / `rootMenu` | Dial ready at root | `rootMenu` (browse), `submenu` (slide up on submenu), `confirmingAction` (slide up on sensitive action), `executing` (slide up on action), `exitArmed` (first slide down at root) |
| `submenu` | Slide up on submenu option | `submenu` (browse), `confirmingAction`, `executing`, `rootMenu` (slide down) |
| `confirmingAction` | Slide up on sensitive action (e.g., Emergency) | `executing` (deliberate confirm), previous menu (slide down / cancel) |
| `executing` / `listening` / `processing` / `speaking` | Action dispatched via `TaskOrchestrator` | `completed`, `failed`, `paused`, `cancelling` |
| `completed` / `failed` / `paused` | Task finishes, errors, or pauses | Previous menu (browse/slide down) or repeat |
| `cancelling` | User cancels active task | Previous menu |
| `exitArmed` | First downward swipe at root | `exiting` (second deliberate downward swipe within 5 s), `rootMenu` (any browse/up/timeout) |
| `exiting` | Second confirmed downward swipe at root | Dismisses dial / minimizes app safely |

## 3. Gesture Recognition & TalkBack Safety (`DialGestureRecognizer`)

- **Browsing options (explore without executing):**
  - Horizontal swipe left/right (`>= 36 dp` primary axis, `1.5x` axis dominance) OR rotary drag around the dial ring OR accessible **Previous Option** / **Next Option** controls (always available for TalkBack touch exploration!).
  - Exploring NEVER executes an action.
- **Slide Up (Select / Enter / Confirm):**
  - Upward vertical swipe (`dy <= -52 dp`, velocity `>= 180 dp/s`, vertical dominance `|dy| >= 1.5 * |dx|`, single-pointer, `250 ms` debounce) OR accessible **Select / Enter** TalkBack button (`>= 64 dp`).
- **Slide Down (Back / Cancel / Exit):**
  - Downward vertical swipe (`dy >= 52 dp`, velocity `>= 180 dp/s`, vertical dominance `|dy| >= 1.5 * |dx|`, single-pointer, `250 ms` debounce) OR accessible **Back / Exit** TalkBack button (`>= 64 dp`).
  - Inside submenu -> restores parent menu and previously focused parent option.
  - At root -> first slide down arms exit ("Slide down again to close Openetra dial."); second slide down within 5 s exits cleanly.
  - During active operation -> never silently cancels emergency; offers explicit cancellation for cancellable tasks.
- **No conflicts:** Ignores multi-touch pointers, ignores gestures starting within `24 dp` of system navigation screen edges, and remains completely independent of camera-based hand gestures.

## 4. Voice Feedback Rules (Zero Backlog)

- Uses existing `AudioArbitrator` -> `AudioBloc` -> `SpeechController`.
- **Latest-selection-only cancellation:** Whenever focus changes (`NextOption` / `PreviousOption`), `AudioArbitrator.announceSelection(...)` immediately interrupts any in-flight selection announcement (`InterruptSpeechRequested`) before speaking the newly focused option (`"<Title>. <Short purpose>."`), guaranteeing zero announcement backlog during rapid browsing.
- Respects user language (`en-IN` and 7 Indic locales), speech rate, and verbosity preference (`concise` vs `detailed`).

## 5. Haptic Vocabulary (`HapticFeedbackManager` -> `HapticsPlugin.kt`)

| Event | Pattern Key | Waveform / Feel |
|---|---|---|
| Option focus changed | `dialFocusTick` | Single short light tick (`18 ms`, amp `85`) |
| Option selected | `dialSelect` | Two crisp short pulses (`28 ms`, `40 ms gap`, `28 ms`) |
| Submenu entered | `dialSubmenuEnter` | Ascending pair (`25 ms` soft -> `50 ms` firmer) |
| Navigate back | `dialNavigateBack` | Descending pair (`50 ms` firmer -> `25 ms` soft) |
| Root exit requested | `dialExitWarn` | Single distinct longer pulse (`110 ms`) |
| Operation started | `dialOpStart` | Medium confirmation pulse (`45 ms`) |
| Operation completed | `dialOpComplete` | Three short recognizable pulses (`25-45-25-45-25 ms`) |
| Operation failed / unavailable | `dialOpError` | Distinct double-long warning (`120-80-120 ms`) |
| Emergency flow initiated | `critical` | High-priority 4-pulse pattern |
