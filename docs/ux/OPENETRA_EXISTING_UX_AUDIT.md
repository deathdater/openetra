# Openetra — Existing Product & UX Audit (Stage A Baseline)

**Audit Date:** 2026-11-23  
**Repository Baseline Commit:** `31fc775` (`v2.2.0-scene-memory-and-object-callouts`)  
**Flutter / Dart:** Flutter `3.22.3` (stable) / Dart `3.4.4`  
**Build Target:** Android `arm64-v8a` offline release APK (`149,083,662` bytes / `149.1 MB`)  
**Baseline Quality Gates:** `flutter analyze` (`0 issues`), `flutter test -r expanded` (`71/71 passing`)

---

## 1. Executive Summary

Openetra is already a functionally complete, offline-first Android assistive visual platform built with Flutter + BLoC (`flutter_bloc ^8.1.6`), Clean Architecture, SQLite v4 (`sqflite`), native Kotlin/C++ integrations (Mirage VLM via Cactus Compute, Tesseract Indic OCR, Silero VAD, LiteRT Hand Landmarks, Android Keystore AES-256-GCM emergency storage, `TorchCallback` intelligent flashlight, `specialUse` floating companion orb, and 10-pattern Android haptics).

However, a rigorous UI/UX, design-system, and accessibility audit reveals **six high-impact opportunities** to elevate Openetra from a strong functional prototype into a calm, cohesive, world-class assistive product — **without touching working AI inference, camera, or native services**:

1. **Dark-Only Theme & 134 Hardcoded Color References:** `lib/app/theme.dart` only provides `buildDarkTheme()`. Screens contain `134` direct `OpenetraTheme.*` static color references, preventing low-vision daylight **Light Theme (`#FFFDF9` Warm White / `#35104F` Deep Aubergine)** support and causing visual drift.
2. **Minimal Shared Component Library:** Only 2 reusable widgets exist (`AccessibleActionTile` and `SpokenStatusBanner`). Cards, section headers, text inputs, confirmation dialogs, empty states, and status badges are re-implemented inline across 13 screens with inconsistent radii, padding, and borders.
3. **Incomplete Typography & Input/Card/Dialog Theming:** Only 5 `TextTheme` slots are configured, with `21` inline hardcoded `fontSize:` declarations across screens and no unified `InputDecorationTheme`, `CardTheme`, `DialogTheme`, or `SliderTheme`.
4. **Settings Screen Navigation Fatigue:** `SettingsScreen` (406 lines) stacks 8 full-height language tiles above speech speed, operating mode, continuous scene mode, assistive controls, and privacy — requiring excessive TalkBack swipes to reach everyday settings.
5. **Screen-Level Semantics & Empty/Status Polish:** `emergency_assistance_screen.dart` and `floating_widget_settings_screen.dart` rely solely on child tile semantics with `0` top-level section header `Semantics`, and several screens lack structured empty/offline/loading components.
6. **Centralized Motion & Theme-Aware Dial Tokens:** `AssistiveDial`, `DialCenter`, and `DialFocusGlyph` have strong interaction mechanics and 20 custom glyphs, but read hardcoded dark-only colors and inline durations rather than centralized `OpenetraPalette` and `OpenetraMotion` tokens.

---

## 2. Repository & Architecture Baseline

- **Entry Point:** `lib/main.dart` -> `OpenetraApp` (`lib/app/app.dart`) with explicit `OpenetraDependencies.bootstrap(...)` (no hidden service locator).
- **State Management:** `flutter_bloc` (`AudioBloc`, `SafetyBloc`, `DeviceResourceBloc`, `VoiceAssistantBloc`, `VisionBloc`, `SceneUnderstandingBloc`, `HazardDetectionBloc`, `SmartReaderBloc`, `ObjectMemoryBloc`, `ModelManagerBloc`, `SettingsBloc`, `EmergencyBloc`, `GestureAutomationBloc`, `FloatingCompanionBloc`, `AssistiveDialBloc`). **Rule:** Reuse `SettingsBloc` and `OpenetraDatabase` for theme preference — do NOT introduce another state-management package.
- **Navigation:** Imperative `Navigator.of(context).push(MaterialPageRoute(...))` from `AssistiveDialPage._openDedicatedRoute` and `HomeScreen`. **Rule:** Preserve all existing routes and contracts.
- **Dependencies (`pubspec.yaml`):** 9 runtime packages (`flutter_bloc`, `equatable`, `sqflite`, `path`, `path_provider`, `crypto`, `flutter_tts`, `permission_handler`, `uuid`). **Zero** third-party animation or UI bloat packages; keep it that way.

---

## 3. Complete Screen-by-Screen UX & Accessibility Audit

| Screen (`lib/features/...`) | Lines | Hardcoded `OpenetraTheme.*` | `Semantics(` | Inline `fontSize:` | Key Audit Findings (10 Dimensions) |
|---|---:|---:|---:|---:|---|
| `assistive_dial_page.dart` | 201 | 0 | 2 | 0 | Strong voice-first home; uses `SpokenStatusBanner` + `AssistiveDial`. Needs theme-aware surface hierarchy and subtle offline-ready status pill. |
| `assistive_dial.dart` + `dial_center.dart` + `dial_focus_glyph.dart` | 1,106 | 23 | 2 | 2 | Excellent radial geometry, 20 bespoke vector glyphs, >=64dp TalkBack controls, reduced-motion support. Hardcodes dark colors; must adopt `OpenetraPalette` + `OpenetraMotion`. |
| `onboarding_screen.dart` | 84 | 0 | 1 | 0 | Clean, honest safety disclaimer and voice test. Can gain subtle brand header emblem and theme-aware styling. |
| `home_screen.dart` (Classic List View) | 389 | 11 | 4 | 0 | Complete parity fallback for list-preference users. Uses raw status text line instead of structured status pill; 11 hardcoded colors. |
| `scene_memory_screen.dart` | 421 | 29 | 1 | 8 | Rich multi-frame recording + multilingual notes. Highest hardcoded color count (29) and inline `fontSize:` (8); needs shared `OpenetraCard`, `OpenetraTextField`, and `OpenetraEmptyState`. |
| `settings_screen.dart` | 406 | 6 | 5 | 0 | Functional but very long flat scroll (8 full-size language tiles at top). Needs Theme Mode selector (Dark / Light / System), logical section cards, and cleaner language picker UX. |
| `object_memory_screen.dart` | 157 | 6 | 2 | 1 | Clear personal object registration & search. Uses raw `TextField` and plain text empty state; needs shared components. |
| `emergency_assistance_screen.dart` | 141 | 4 | 0 | 0 | Safe two-step confirmation & dry-run test. Missing explicit `Semantics(header: true)` landmarks; 4 hardcoded colors. |
| `emergency_contacts_screen.dart` | 223 | 11 | 2 | 3 | Encrypted Keystore contact management works well. 11 hardcoded colors, inline `InputDecoration`, plain empty state. |
| `flashlight_settings_screen.dart` | 86 | 0 | 1 | 0 | Clean and concise. Will automatically inherit upgraded `OpenetraTheme` & shared tiles. |
| `floating_widget_settings_screen.dart` | 161 | 9 | 0 | 2 | Clear overlay permission guidance. Missing header `Semantics`, 9 hardcoded colors. |
| `gesture_automation_screen.dart` | 283 | 11 | 2 | 2 | Solid opt-in & enrollment UX. 11 hardcoded colors and inline status cards. |
| `model_manager_screen.dart` | 98 | 3 | 1 | 0 | Clear offline pack inventory. Needs shared `OpenetraCard` + `OpenetraStatusBadge`. |
| `shopping_screen.dart` | 190 | 11 | 2 | 0 | Functional barcode & product assistant. 11 hardcoded colors; needs shared card & empty state. |

**Total Hardcoded `OpenetraTheme.*` References in UI:** `134` (including `10` in `accessible_action_tile.dart`).

---

## 4. Feature-to-Implementation-to-Test Traceability Baseline

| Feature | Implementation | Existing Automated Verification | Status |
|---|---|---|---|
| Intelligent Assistive Dial + 20 Glyphs + Haptics | `lib/features/dial/*`, `HapticFeedbackManager`, `HapticsPlugin.kt` | `test/features/dial/assistive_dial_test.dart` (7 tests) | Protected — Passing |
| Scene Understanding + Continuous Mode + 8 Languages | `SceneUnderstandingEngine`, `OpenetraLocalizer`, `IndicSceneLexicon` | `scene_understanding_engine_test.dart`, `openetra_localizer_test.dart`, `assistive_dial_test.dart` | Protected — Passing |
| Recorded Scene Memory & Registered Object Callouts | `RecordedSceneRecord`, `RegisteredObjectSceneMatcher`, `SceneMemoryScreen` | `recorded_scene_and_object_callout_test.dart` (5 tests) | Protected — Passing |
| Smart Reader (Mirage Latin + Tesseract Indic OCR) | `OcrRouter`, `NativeIndicOcrProvider`, `ReadingOrderReconstructor` | `ocr_router_and_reading_order_test.dart`, `native_indic_providers_test.dart` | Protected — Passing |
| Hazard Awareness & Safety Policy Guard | `HazardIntelligenceEngine`, `SafetyPolicyGuard` | `hazard_intelligence_engine_test.dart`, `safety_policy_and_guard_test.dart` | Protected — Passing |
| Personal Object Memory & Currency Fusion | `ObjectMemoryBloc`, `CurrencyRecognitionService`, `NativeEmbeddingProvider` | `workflows_d_e_test.dart`, `embeddings_and_currency_fusion_test.dart` | Protected — Passing |
| Emergency Assistance (Keystore AES-256-GCM + Dialer) | `EmergencyBloc`, `EmergencyAssistanceService`, `ProtectedContactStore` | `emergency_assistance_test.dart` | Protected — Passing |
| Intelligent Flashlight, Gestures, Floating Companion | `IntelligentFlashlightController`, `GestureAutomationBloc`, `FloatingCompanionBloc` | `intelligent_flashlight_test.dart`, `gesture_evaluation_test.dart`, `floating_companion_test.dart` | Protected — Passing |
| Offline Storage (SQLite v4) & Privacy Wipe | `OpenetraDatabase`, `SettingsBloc` | `openetra_database_and_checksum_test.dart`, `shared_architecture_test.dart`, `v1_release_readiness_test.dart` | Protected — Passing |

---

## 5. Regression Risk Register

| Risk ID | Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|---|
| R-01 | Theme migration breaks contrast in Light or Dark mode | Medium | High | Define WCAG AAA (`>= 7:1` body, `>= 4.5:1` large/UI) `OpenetraPalette` tokens in a `ThemeExtension` and add automated contrast & theme-switching widget tests. |
| R-02 | Changing `AccessibleActionTile` or `SpokenStatusBanner` breaks existing widget tests | Medium | High | Preserve all existing constructor parameters, text labels, >=64dp heights, and `Semantics` labels as backward-compatible contracts. |
| R-03 | Settings reorganization breaks `v1_release_readiness_test.dart` (`Delete All Personal Data` tap/scroll) | Medium | High | Keep exact button titles and `SettingsScreen` scrollability; run full test suite after every stage. |
| R-04 | Dial visual updates introduce gesture regressions or continuous idle GPU animations | Low | High | Preserve `DialGestureAnalyzer` & `DialCenter.shouldAnimatePhase` (zero idle animation) untouched; add reduced-motion + light/dark dial widget tests. |
| R-05 | Modifying AI, camera, or native Android code accidentally | Low | Critical | **Hard boundary:** Do not touch `core/inference/`, `core/camera/`, `core/safety/`, or `android/` native services during UI/UX stages. |

---

## 6. Approved Phased Transformation Plan

- **Stage A (Current — Complete):** Audit, baseline verification (`71/71` tests, `0` analyze issues), risk register, traceability matrix.
- **Stage B (Design Foundation):** Upgrade `lib/app/theme.dart` with semantic `OpenetraPalette` (`ThemeExtension`) + `OpenetraSpacing` + `OpenetraMotion`, add full **Light Theme (`#FFFDF9` Warm White)** alongside refined **Dark Theme (`#120B1A` Deep Aubergine)**, persist `ThemeMode` via `SettingsBloc` + `OpenetraDatabase`, and expand `lib/shared/widgets/` with reusable accessible components (`OpenetraSectionHeader`, `OpenetraCard`, `OpenetraStatusBadge`, `OpenetraEmptyState`, `OpenetraTextField`, `OpenetraConfirmDialog`) while keeping `AccessibleActionTile` & `SpokenStatusBanner` 100% backward-compatible. Document in `docs/ux/OPENETRA_DESIGN_SYSTEM.md`.
- **Stage C (Main Home & Navigation Polish):** Elevate `AssistiveDialPage`, `OnboardingScreen`, and `HomeScreen` with restrained brand presence, clear offline/readiness status badges, and zero hardcoded colors.
- **Stage D (Dial & Voice-First Interaction Polish):** Make `AssistiveDial`, `DialCenter`, and `DialFocusGlyph` fully theme-aware (Dark + Light) with `OpenetraMotion` tokens and crisp focus/selection indicators. Document in `docs/ux/OPENETRA_DIAL_INTERACTION_SPEC.md`.
- **Stage E (Feature Screens Transformation):** Migrate all remaining feature screens (`SettingsScreen` with Appearance/Theme toggle & cleaner grouped language UX, `SceneMemoryScreen`, `ObjectMemoryScreen`, `EmergencyAssistanceScreen`, `EmergencyContactsScreen`, `FloatingWidgetSettingsScreen`, `GestureAutomationScreen`, `ModelManagerScreen`, `ShoppingScreen`) off hardcoded `OpenetraTheme.*` onto semantic `OpenetraPalette` and shared components.
- **Stage F (Accessibility, Dynamic Scaling & Regression Hardening):** Add dedicated widget tests for Light/Dark theme switching, `2.0x` large text scaling without overflow, WCAG contrast verification, reduced motion, and full `flutter analyze` + `flutter test` + arm64 APK build.
- **Stage G (Final Documentation & Release Notes):** Complete all remaining required UX, Architecture, QA, Accessibility, Performance, Traceability, and Release Notes documents with verified measured results.
