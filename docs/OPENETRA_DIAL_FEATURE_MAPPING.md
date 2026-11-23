# Openetra Feature-to-Dial Mapping (Phase 1)

**Rule:** Every existing Openetra feature is mapped to an explicit, accessible destination. Zero features are removed or silently hidden.

| Existing Feature / Workflow | Destination Category | Exact Entry Point | Underlying Service Reused |
|---|---|---|---|
| Describe Surroundings | **Primary Dial + Submenu** (`describe_surroundings`) | Root Option 1 -> Submenu (`Describe current scene`, `Repeat last description`, `Return`) | `TaskOrchestrator` -> `OpenetraCoordinator.runDescribeSurroundings` |
| Smart Reader / Read Text (Latin + 7 Indic scripts) | **Primary Dial + Submenu** (`read_text`) | Root Option 2 -> Submenu (`Read visible text`, `Repeat recognised text`, `Return`) | `TaskOrchestrator` -> `OpenetraCoordinator.runSmartReader` |
| Personal Object Memory & Search | **Primary Dial + Submenu** (`find_object`) | Root Option 3 -> Submenu (`Find registered object`, `Manage registered objects` -> `ObjectMemoryScreen`, `Repeat last result`, `Return`) | `TaskOrchestrator` -> `OpenetraCoordinator.runFindObject` / `ObjectMemoryScreen` |
| Hazard Awareness Cue Assessment | **Primary Dial + Submenu** (`hazard_assistance`) | Root Option 4 -> Submenu (`Scan visible hazard cues`, `Toggle continuous hazard mode`, `Repeat last alert`, `Return`) | `TaskOrchestrator` -> `OpenetraCoordinator.runHazardScan` / `toggleHazardLoop` |
| Offline Voice Assistance | **Primary Dial + Submenu** (`voice_assistance`) | Root Option 5 -> Submenu (`Start voice command`, `Repeat last response`, `Stop speaking`, `Return`) | `OpenetraCoordinator.handleVoiceCommand` / `AudioBloc` |
| Emergency Assistance | **Primary Dial + Submenu** (`emergency_assistance`) | Root Option 6 -> Submenu (`Open Emergency Confirmation` -> `EmergencyAssistanceScreen`, `Test Emergency Flow`, `Return`) — requires explicit confirmation | `EmergencyBloc` / `EmergencyAssistanceScreen` |
| Intelligent Flashlight | **Primary Dial + Submenu** (`flashlight`) | Root Option 7 -> Submenu (`Toggle Flashlight`, `Turn On`, `Turn Off`, `Flashlight Settings`, `Return`) | `IntelligentFlashlightController` / `FlashlightSettingsScreen` |
| Currency Note Identification | **Secondary Tool** (`more_tools` submenu) | Root Option 8 (`More tools`) -> `Identify currency note` | `TaskOrchestrator` -> `OpenetraCoordinator.runIdentifyCurrency` |
| Shopping & Barcode Assistant | **Secondary Tool** (`more_tools` submenu) | Root Option 8 (`More tools`) -> `Shopping & barcode scan` -> `ShoppingScreen` | `ShoppingScreen` / `ShoppingAssistantService` |
| Classic List Mode (`HomeScreen`) | **Existing Dedicated Workflow** | Root Option 8 (`More tools`) -> `Classic List View` + Settings toggle | `HomeScreen` (preserved intact) |
| Custom Hand Gestures | **Configuration Screen** | Settings (`Assistive Controls`) + `More tools` -> `GestureAutomationScreen` | `GestureAutomationBloc` |
| Floating Assistive Companion | **Configuration Screen** | Settings (`Assistive Controls`) -> `FloatingWidgetSettingsScreen` (also syncs compact dial/state glow) | `FloatingCompanionBloc` / `FeedbackDispatcher` |
| Offline AI Models & Checksums | **Configuration Screen** | Settings (`AI & Offline`) -> `ModelManagerScreen` | `ModelManagerBloc` |
| Language, Speech Speed, Dial/Haptics, Privacy Wipe | **Configuration Screen** | Top-bar Settings button + Root Option 8 (`More tools`) -> `SettingsScreen` (7 organized categories) | `SettingsBloc`, `DeviceResourceBloc`, `AudioBloc` |
| First-Run Safety Disclaimer | **Existing Dedicated Workflow** | `OnboardingScreen` on first launch | `SettingsBloc` |
