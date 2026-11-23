# Openetra Software Architecture

## 1. Four-Layer Intelligence Separation

Openetra strictly separates AI reasoning into four independent responsibilities so no single model or prompt owns perception, context, and safety simultaneously:

```text
+-------------------------------------------------------------------+
| 1. VISUAL PERCEPTION LAYER                                        |
|    MirageInferenceProvider -> MethodChannel -> Kotlin -> JNI/C++  |
|    -> libcactus.a -> mirage.cact                                  |
|    Output: Raw VisionObservation (bboxes, labels, masks, text)    |
+-------------------------------------------------------------------+
                                  |
                                  v
+-------------------------------------------------------------------+
| 2. SPECIALIST INTELLIGENCE LAYER (Pluggable Registry & Router)    |
|    - ScriptDetector + OcrRouter (Latin / Devanagari / Kannada...) |
|    - CurrencyClassifierProvider + OCR numeral verification        |
|    - Optional DepthProvider, EmbeddingProvider, Barcode           |
|    - Offline AsrProvider (IndicConformer) & TtsProvider           |
+-------------------------------------------------------------------+
                                  |
                                  v
+-------------------------------------------------------------------+
| 3. CONTEXTUAL INTELLIGENCE LAYER                                  |
|    SceneUnderstandingEngine + ContextualQueryResolver             |
|    - Entity deduplication (Mirage id), relative geometry          |
|    - Rolling SceneGraph memory & temporal scene diff              |
|    - Natural speech synthesis & offline follow-up QA              |
+-------------------------------------------------------------------+
                                  |
                                  v
+-------------------------------------------------------------------+
| 4. SAFETY INTELLIGENCE LAYER (Independent Safety Gate)            |
|    HazardIntelligenceEngine + IoUTracker + OpenetraSafetyPolicy   |
|    - Image quality & thermal degradation evaluation               |
|    - 5-factor confidence separation                               |
|    - SafetySpeechGuard (blocks unsafe claims) + SQLite SafetyLog  |
+-------------------------------------------------------------------+
```

---

## 2. Flutter Clean Architecture & BLoC Layering

```text
lib/
├── app/                     # Theme (WCAG AAA dark), DI container, App root, routes
├── core/
│   ├── accessibility/       # TalkBack Semantics helpers, AccessibilityAnnouncer
│   ├── audio/               # SpeechController (mic-gating), HapticFeedbackService, AudioBloc
│   ├── camera/              # CameraControllerBridge (MethodChannel com.openetra.app/camera)
│   ├── domain/entities/     # 18 typed immutable Equatable domain contracts
│   ├── errors/              # OpenetraFailure hierarchy
│   ├── inference/           # AIModelRegistry, AIModelOrchestrator, Mirage provider & parser
│   ├── resource_management/ # DeviceResourceManager, thermal/battery cadence, DeviceResourceBloc
│   ├── safety/              # OpenetraSafetyPolicy, SafetySpeechGuard, SafetyBloc
│   └── storage/             # OpenetraDatabase (SQLite), ModelChecksumVerifier
├── features/
│   ├── onboarding/
│   ├── voice_assistant/     # VoiceAssistantBloc, VoiceIntentRouter, AccessibleHomeScreen
│   ├── vision_explorer/     # VisionBloc
│   ├── scene_understanding/ # SceneUnderstandingEngine, ContextualQueryResolver, SceneUnderstandingBloc
│   ├── hazard_detection/    # HazardIntelligenceEngine, IoUTracker, HazardDetectionBloc
│   ├── smart_reader/        # ScriptDetector, OcrRouter, ReadingOrderReconstructor, SmartReaderBloc
│   ├── object_memory/       # PersonalObjectRepository, ObjectMemoryBloc
│   ├── currency/            # CurrencyRecognitionService, CurrencyBloc
│   ├── shopping/            # Layered barcode + local catalog + OCR stub/interface
│   ├── navigation/          # Local orientation / breadcrumb guidance hooks
│   ├── model_manager/       # Registry inspection, checksum verification, ModelManagerBloc
│   └── settings/            # Language, speech speed, operating mode, data wipe, SettingsBloc
└── shared/                  # Accessible primary tiles & semantic widgets
```

---

## 3. Native Android Architecture (Kotlin + C++)

```text
Flutter Platform Channels (MethodChannel)
 ├── com.openetra.app/mirage    -> MirageEnginePlugin.kt (single-thread ExecutorService)
 │                                 -> MirageNativeBridge.kt (JNI)
 │                                 -> openetra_mirage_jni.cpp (std::mutex + 16MB buffer)
 │                                 -> libcactus.a (Cactus 4.1.4) + mirage.cact
 ├── com.openetra.app/camera    -> CameraXCaptureManager.kt (YUV_420_888 -> RGB24 + pitch)
 ├── com.openetra.app/resources -> DeviceResourcePlugin.kt (Battery, Thermal, RAM, TTS Voices)
 └── com.openetra.app/haptics   -> HapticsPlugin.kt (VibrationEffect waveforms)
```
