# Android Permission Matrix

**Product:** Openetra  
**Verified Release Artifact:** `build/app/outputs/flutter-apk/app-release.apk` (`148,818,998` bytes, `targetSdk 35`, `minSdk 26`)

---

## 1. Declared Permissions (`aapt2 dump permissions app-release.apk`)

| Permission | Category | Feature(s) | Requested When | Behavior If Denied / Revoked |
|---|---|---|---|---|
| `android.permission.CAMERA` | Dangerous (Runtime) | Scene, Reader, Hazards, Objects, Shopping, Foreground Gestures | On user action requiring camera | `CapabilityAvailabilityService` blocks camera action cleanly and speaks honest notice; Emergency Assistance & manual torch (via CameraManager) remain usable |
| `android.permission.RECORD_AUDIO` | Dangerous (Runtime) | Offline voice commands | On user voice tap | Text command box and touch/gesture/overlay actions remain fully usable |
| `android.permission.VIBRATE` | Normal | Tactile confirmation & hazard haptics | Install-time | N/A |
| `android.permission.SYSTEM_ALERT_WINDOW` | Special App Access | Floating Assistive Companion orb | Opt-in via Android Settings (`ACTION_MANAGE_OVERLAY_PERMISSION`) | Floating companion remains off; revocation detected on `RefreshOverlayPermission` and cleanly stops service |
| `android.permission.FOREGROUND_SERVICE` | Normal | `FloatingCompanionService` | Install-time | Service only starts when user explicitly enables Floating Companion |
| `android.permission.FOREGROUND_SERVICE_SPECIAL_USE` | Normal (API 34+) | `FloatingCompanionService` (`specialUse` + `PROPERTY_SPECIAL_USE_FGS_SUBTYPE`) | Install-time | Required by Android 14/15 for persistent assistive overlay service |
| `android.permission.POST_NOTIFICATIONS` | Dangerous (API 33+) | Persistent non-sensitive companion notification | When enabling Floating Companion | Service stays honest; user guided to enable notifications for Hide & Stop shortcut |

## 2. Explicitly Omitted Permissions (Release Build)

- `android.permission.INTERNET` — **Removed** (`src/release/AndroidManifest.xml`, verified absent via `aapt2`)
- `android.permission.ACCESS_NETWORK_STATE` — **Removed** (verified absent via `aapt2`)
- `android.permission.CALL_PHONE` — **Omitted** (Emergency uses `Intent.ACTION_DIAL` with `<queries>` only)
- `android.permission.ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` — **Omitted**
- `android.permission.READ_CONTACTS` — **Omitted** (user manually enters trusted contacts)

## 3. Verification Classification

- **Implemented and verified:** Exact permission list verified via `aapt2 dump permissions build/app/outputs/flutter-apk/app-release.apk` and runtime policy gating verified in `shared_architecture_test.dart` and `floating_companion_test.dart`.
- **Implemented but not yet physically validated:** Live OEM permission-revocation lifecycle dialogs across physical Android 12–15 devices.
