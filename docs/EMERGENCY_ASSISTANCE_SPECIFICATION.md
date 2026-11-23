# Emergency Assistance Specification

**Product:** Openetra  
**Status Summary:** Core workflow implemented and verified on host + Android 15 ARM64 emulator; cellular dialer handoff and real TalkBack emergency UX remain **Implemented but not yet physically validated**.

---

## 1. Purpose & Safety Boundaries

Emergency Assistance enables a blind user to initiate contact with a pre-configured trusted person through a deliberate, accessible, audio-first confirmation flow.

- **Never implies call connection:** Openetra opens the Android phone dialer (`Intent.ACTION_DIAL`) pre-populated with the trusted number; it never claims a call connected or that cellular/emergency services are reachable offline.
- **No `CALL_PHONE` by default:** Openetra intentionally omits `android.permission.CALL_PHONE` so accidental activation cannot silently place an unconfirmed call.
- **Independent of visual/AI subsystems:** Requires zero camera, Mirage VLM, OCR, flashlight, or gesture availability.

## 2. Architecture & Actual Repository Locations

| Component | Path | Responsibility |
|---|---|---|
| Native Keystore & Dialer Plugin | `android/app/src/main/kotlin/com/openetra/app/emergency/EmergencyAssistancePlugin.kt` | Android Keystore AES-256-GCM (`openetra_emergency_aes_gcm_v1`) encrypted storage (`filesDir/secure/emergency_contacts.enc`), `ACTION_DIAL` launch, airplane/dialer/telephony checks, zero PII logging |
| Domain Entity | `lib/features/emergency/domain/trusted_contact.dart` | `TrustedContact` (`maskedPhone()`, PII-redacted `toString()`), `EmergencyActionMode`, `EmergencyCapabilities` |
| Protected Store Bridge | `lib/features/emergency/data/protected_contact_store.dart` | `NativeEncryptedContactStore` (`com.openetra.app/emergency`) and `InMemoryProtectedContactStore` |
| Domain Service | `lib/features/emergency/domain/emergency_assistance_service.dart` | Phone validation/sanitization, primary contact selection, confirmation prompt, dry-run execution, error handling |
| State Management | `lib/features/emergency/bloc/emergency_bloc.dart` | Explicit confirmation state machine (`RequestEmergencyInitiation` -> `ConfirmEmergencyInitiation` / `CancelEmergencyInitiation`) |
| Accessible UI | `lib/features/emergency/presentation/emergency_assistance_screen.dart`, `emergency_contacts_screen.dart` | High-contrast >=64dp tiles, TalkBack announcements, safe test mode, masked digits |
| Data Wipe Integration | `lib/features/settings/bloc/settings_bloc.dart`, `lib/app/app.dart` | `DeleteAllUserDataRequested` clears `emergency_contacts.enc` alongside SQLite user data |

## 3. Verification Classification

- **Implemented and verified:**
  - Android Keystore AES-256-GCM encryption/decryption roundtrip with zero plaintext phone/name in `emergency_contacts.enc` (`AssistiveControlsInstrumentedTest`, Android 15 ARM64 emulator).
  - Contact CRUD, primary switching, `toString()` PII redaction, confirmation/cancel gating, dry-run zero-dial guarantee, airplane/missing-dialer degradation, voice intent routing (`emergency`, `आपातकाल`), and `SettingsBloc` wipe (`test/features/emergency/emergency_assistance_test.dart`).
- **Implemented but not yet physically validated:**
  - Live `Intent.ACTION_DIAL` handoff with physical SIM / cellular network and TalkBack screen-reader focus traversal into the OEM phone dialer.
- **Partially implemented:** None.
- **Proposed:** Optional dual-SIM preferred-line guidance if requested in a future release.
- **Blocked by platform, hardware, dependency or product decision:** Direct silent `CALL_PHONE` execution is intentionally excluded by product safety policy.
