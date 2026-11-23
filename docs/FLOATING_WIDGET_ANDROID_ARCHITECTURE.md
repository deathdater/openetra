# Floating Assistive Widget — Android Architecture

**Product:** Openetra  
**Target SDK:** Android 15 (`targetSdk = 35`, `compileSdk = 36`, `minSdk = 26`)

---

## 1. Native Component Map

| File | Role |
|---|---|
| `android/app/src/main/kotlin/com/openetra/app/floating/FloatingWidgetState.kt` | 10-state enum (`IDLE`..`EMERGENCY_FLOW`) with high-contrast colors, `allowsPulseAnimation` flag, and TalkBack strings |
| `android/app/src/main/kotlin/com/openetra/app/floating/FloatingOrbView.kt` | Custom `View` rendering radial glow + core disc, `ValueAnimator` gating (`IDLE`/`PAUSED`/`COMPLETED`/reduced-motion), gesture detector (tap/double-tap/long-press/drag), and `AccessibilityNodeInfo` actions |
| `android/app/src/main/kotlin/com/openetra/app/floating/FloatingCompanionService.kt` | `specialUse` foreground `Service` managing `WindowManager` `TYPE_APPLICATION_OVERLAY` view, snap-to-edge, rotation updates, persistent notification, and Category A vs Category C action dispatch |
| `android/app/src/main/kotlin/com/openetra/app/floating/FloatingCompanionPlugin.kt` | `MethodChannel("com.openetra.app/floating_companion")` bridging Flutter `NativeFloatingCompanionBridge` to service lifecycle and action callbacks |
| `android/app/src/main/kotlin/com/openetra/app/MainActivity.kt` | Registers/releases plugin and forwards `EXTRA_ASSISTIVE_ACTION` via `onNewIntent` and initial launch intent |

## 2. Manifest & Android 14/15 `specialUse` FGS Compliance

Declared in `android/app/src/main/AndroidManifest.xml` (while `src/release/AndroidManifest.xml` continues stripping `INTERNET` and `ACCESS_NETWORK_STATE`):

- `android.permission.SYSTEM_ALERT_WINDOW`
- `android.permission.FOREGROUND_SERVICE`
- `android.permission.FOREGROUND_SERVICE_SPECIAL_USE`
- `android.permission.POST_NOTIFICATIONS`
- `<service android:name=".floating.FloatingCompanionService" android:exported="false" android:foregroundServiceType="specialUse">` with `<property android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE" android:value="persistent_assistive_overlay_control" />`

## 3. Window & Lifecycle Safety

- Verifies `Settings.canDrawOverlays(this)` before starting foreground or calling `windowManager.addView(...)`.
- Uses `FLAG_NOT_FOCUSABLE | FLAG_LAYOUT_IN_SCREEN` so the orb never steals keyboard focus from underlying apps.
- Cancels `ValueAnimator` in `onDetachedFromWindow()` and removes the overlay view in `onDestroy()` and `ACTION_STOP`/`ACTION_HIDE`.

## 4. Verification Classification

- **Implemented and verified:** Manifest `FOREGROUND_SERVICE_TYPE_SPECIAL_USE` declaration, `FloatingOrbView` animator/reduced-motion/TalkBack invariants (`AssistiveControlsInstrumentedTest`), and `app-release.apk` R8 build & `aapt2` permission check.
- **Implemented but not yet physically validated:** Live `WindowManager` overlay rendering over third-party apps on physical Android 12–15 handsets.
- **Partially implemented / Proposed / Blocked:** None.
