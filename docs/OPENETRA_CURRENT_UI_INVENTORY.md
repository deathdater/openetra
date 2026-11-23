# Openetra Current UI Inventory (Phase 0 Audit)

**Baseline Version:** `v1.5.0-assistive-controls-verified` (`3d1a365`)  
**Audit Date:** 2026-11-23

---

## 1. Existing Screens Inventory

| Screen | Location | Primary Role | State / Dependencies |
|---|---|---|---|
| `OnboardingScreen` | `lib/features/onboarding/presentation/onboarding_screen.dart` | First-run safety disclaimer acceptance & setup completion | `SettingsBloc` (`CompleteOnboarding`) |
| `HomeScreen` | `lib/features/voice_assistant/presentation/home_screen.dart` | Scrollable vertical list of primary action tiles (`Stop Speaking`, `Describe Surroundings`, `Hazard Awareness Scan`, `Read Text`, `Identify Currency Note`, `Personal Object Memory`, `Shopping Assistant`, `Continuous Hazard Mode`, `Emergency Assistance`, `Flashlight`, offline voice command input, `Model Manager`, `Settings`) | `OpenetraCoordinator`, `VoiceAssistantBloc`, `SafetyBloc`, `DeviceResourceBloc`, `SettingsBloc` |
| `ObjectMemoryScreen` | `lib/features/object_memory/presentation/object_memory_screen.dart` | Register personal objects with camera 96-dim visual embeddings, search, view last-seen, delete | `ObjectMemoryBloc`, `OpenetraCoordinator` |
| `ShoppingScreen` | `lib/features/shopping/presentation/shopping_screen.dart` | Barcode scanning (`ML Kit 17.3.0`), SQLite `local_products` lookup, OCR & Mirage fallback | `OpenetraCoordinator` |
| `ModelManagerScreen` | `lib/features/model_manager/presentation/model_manager_screen.dart` | Inspect bundled & optional offline models (`Mirage`, 7 Indic Tesseract packs, ML Kit Devanagari, Silero VAD, MediaPipe Hand Landmarks), SHA-256 verification status | `ModelManagerBloc` |
| `EmergencyAssistanceScreen` | `lib/features/emergency/presentation/emergency_assistance_screen.dart` | Confirmed trusted-contact `ACTION_DIAL` flow + safe dry-run verification mode + airplane/telephony warnings | `EmergencyBloc`, `AudioArbitrator` |
| `EmergencyContactsScreen` | `lib/features/emergency/presentation/emergency_contacts_screen.dart` | Add/edit/select-primary/remove AES-256-GCM encrypted trusted contacts & action preference | `EmergencyBloc` |
| `FlashlightSettingsScreen` | `lib/features/flashlight/presentation/flashlight_settings_screen.dart` | Manual torch toggle, opt-in auto low-light mode, lux threshold slider, ownership & hardware telemetry | `IntelligentFlashlightController` |
| `GestureAutomationScreen` | `lib/features/gestures/presentation/gesture_automation_screen.dart` | Opt-in foreground hand-gesture recognition, 5-sample enrolment, test mode, emergency opt-in safeguard | `GestureAutomationBloc` |
| `FloatingWidgetSettingsScreen` | `lib/features/floating_companion/presentation/floating_widget_settings_screen.dart` | `SYSTEM_ALERT_WINDOW` permission flow, floating orb toggle, tap/long-press action mapping, reduced-motion, orb size | `FloatingCompanionBloc` |
| `SettingsScreen` | `lib/features/settings/presentation/settings_screen.dart` | Language selection (8 Indian locales), speech rate slider, operating mode, links to Emergency/Flashlight/Gestures/Floating Companion, two-step `Delete All Personal Data` | `SettingsBloc`, `DeviceResourceBloc`, `AudioBloc` |

## 2. Shared UI, Audio, Haptic & Orchestration Infrastructure

- **Theme:** `lib/app/theme.dart` (`OpenetraTheme`) — currently pure black (`#000000`) + yellow (`#FFD600`). Will evolve to Openetra's Deep Aubergine / Dark Plum / Refined Lavender / Warm Orange brand palette while preserving WCAG AAA contrast.
- **Shared Widgets:** `lib/shared/widgets/accessible_action_tile.dart` (`AccessibleActionTile`, `SpokenStatusBanner`).
- **Audio & TTS:** `SpeechController` (`flutter_tts`), `AudioBloc`, `AccessibilityAnnouncer`, `AudioArbitrator`, `VoiceIntentRouter`, `OpenetraLocalizer`.
- **Haptics:** `HapticFeedbackService` (`com.openetra.app/haptics`) -> `HapticsPlugin.kt` (currently 5 patterns: `confirm`, `caution`, `warning`, `critical`, `degraded`).
- **Action Routing & Orchestration:** `AssistiveActionRouter`, `CapabilityAvailabilityService`, `TaskOrchestrator`, `CameraResourceManager`, `PermissionCoordinator`, `FeedbackDispatcher`.
