# Assistive Controls Privacy & Data Governance

**Product:** Openetra  
**Baseline Guarantee:** Offline-first, zero cloud AI, zero analytics telemetry, zero network permissions in `app-release.apk`.

---

## 1. Feature-by-Feature Privacy Controls

| Feature | Data Stored Locally | Protection Mechanism | Deletion / Wipe Path |
|---|---|---|---|
| **Emergency Assistance** | Trusted contact names, phone numbers, relationship, primary flag | Android Keystore AES-256-GCM (`openetra_emergency_aes_gcm_v1`) in `filesDir/secure/emergency_contacts.enc`; `TrustedContact.toString()` redacts numbers to `***XXXX`; zero PII logging in Kotlin or Dart | Per-contact delete + `SettingsScreen` -> `Delete All Personal Data` (`SettingsBloc.onClearProtectedStorage`) |
| **Intelligent Flashlight** | Opt-in auto boolean, lux threshold (`assistive_preferences` SQLite v3) | No camera frames stored; `meanLuma` is an ephemeral scalar | `OpenetraDatabase.deleteAllUserData()` |
| **Custom Hand Gestures** | Gesture name, mapped `AssistiveActionId`, 84-dim L2-normalized landmark descriptors (`custom_gestures` SQLite v3) | Zero raw camera frames or video retained on disk; foreground opt-in only | Per-gesture delete + `OpenetraDatabase.deleteAllUserData()` |
| **Floating Companion** | Enabled flag, tap/long-press action IDs, orb size, reduced motion (`assistive_preferences` SQLite v3) | Persistent notification displays only generic status text (never OCR, scene descriptions, or contact info); `FeedbackDispatcher` strips sensitive details before publishing to overlay sink | `OpenetraDatabase.deleteAllUserData()` + immediate **Hide & Stop** notification action |

## 2. Release APK Network Isolation Proof

Verified via `aapt2 dump permissions build/app/outputs/flutter-apk/app-release.apk`:
- `android.permission.INTERNET`: **ABSENT**
- `android.permission.ACCESS_NETWORK_STATE`: **ABSENT**
- `android.permission.CALL_PHONE`: **ABSENT**

## 3. Verification Classification

- **Implemented and verified:** Keystore AES-256-GCM ciphertext inspection (zero plaintext phone/name in `.enc` on Android 15 emulator), `TrustedContact.toString()` redaction test, `FeedbackDispatcher` sanitization test, `SettingsBloc` wipe clearing encrypted contacts + SQLite v3 tables, and `aapt2` release permission audit.
- **Implemented but not yet physically validated:** Independent third-party security/privacy audit on physical retail devices.
- **Partially implemented / Proposed / Blocked:** None.
