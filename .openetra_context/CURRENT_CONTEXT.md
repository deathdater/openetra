# Openetra Local Engineering Context

**Current Version:** `1.2.0-emergency-flashlight`  
**Phase:** Assistive Controls Milestone 2 (Phases 2–4) — Emergency Assistance & Intelligent Flashlight  
**Last Updated:** 2026-11-23  
**Git Branch:** `main`  

## Delivered in `v1.2.0-emergency-flashlight`
- **Feature A (Emergency Assistance):** `EmergencyAssistancePlugin.kt` (Android Keystore AES-256-GCM contact store + `Intent.ACTION_DIAL` handoff, zero PII logging), `TrustedContact` with masked phone & redacted `toString()`, `ProtectedContactStore`, `EmergencyAssistanceService`, `EmergencyBloc`, `EmergencyAssistanceScreen`, `EmergencyContactsScreen`, dry-run test flow, airplane/dialer capability notices, and `SettingsBloc` wipe integration.
- **Feature B (Intelligent Flashlight):** `FlashlightPlugin.kt` (`CameraManager.TorchCallback` external-owner protection, CameraX + CameraManager torch routing, opt-in `Sensor.TYPE_LIGHT`), `CameraXCaptureManager` `meanLuma` sharing without a second camera session, `FlashlightPolicyEvaluator` (15/45 lux & 48/90 luma hysteresis, 4 s dwell, 1.5 s debounce, 180 s cutoff, battery <=15% / thermal >=severe pause), `IntelligentFlashlightController`, and `FlashlightSettingsScreen`.
- **Voice & App Wiring:** Extended `VoiceIntentRouter`, `OpenetraCoordinator`, `OpenetraDependencies`, `HomeScreen`, and `SettingsScreen`.
- **Verification:** `flutter analyze` (`No issues found!`) and `flutter test -r expanded` (`52/52` passing).
