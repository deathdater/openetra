import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/accessibility/accessibility_announcer.dart';
import '../core/audio/bloc/audio_bloc.dart';
import '../core/audio/haptic_feedback_service.dart';
import '../core/audio/native_offline_asr_provider.dart';
import '../core/audio/speech_controller.dart';
import '../core/camera/camera_controller_bridge.dart';
import '../core/inference/ai_model_orchestrator.dart';
import '../core/inference/ai_model_registry.dart';
import '../core/inference/mirage/mirage_inference_provider.dart';
import '../core/inference/model_provider.dart';
import '../core/resource_management/bloc/device_resource_bloc.dart';
import '../core/resource_management/device_resource_manager.dart';
import '../core/safety/bloc/safety_bloc.dart';
import '../core/safety/openetra_safety_policy.dart';
import '../core/storage/openetra_database.dart';
import '../features/hazard_detection/bloc/hazard_detection_bloc.dart';
import '../features/hazard_detection/domain/hazard_intelligence_engine.dart';
import '../features/model_manager/bloc/model_manager_bloc.dart';
import '../features/object_memory/bloc/object_memory_bloc.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/scene_understanding/bloc/scene_understanding_bloc.dart';
import '../features/scene_understanding/domain/contextual_query_resolver.dart';
import '../features/scene_understanding/domain/scene_understanding_engine.dart';
import '../features/settings/bloc/settings_bloc.dart';
import '../features/smart_reader/bloc/smart_reader_bloc.dart';
import '../features/smart_reader/data/native_indic_ocr_provider.dart';
import '../features/smart_reader/domain/ocr_router.dart';
import '../features/vision_explorer/bloc/vision_bloc.dart';
import '../features/voice_assistant/bloc/voice_assistant_bloc.dart';
import '../features/voice_assistant/presentation/home_screen.dart';
import 'openetra_coordinator.dart';
import 'theme.dart';

/// Dependency graph built explicitly without hidden globals for testability.
class OpenetraDependencies {
  OpenetraDependencies({
    required this.database,
    required this.registry,
    required this.resourceManager,
    required this.visionProvider,
    required this.cameraSource,
    required this.speechController,
    required this.hapticService,
    required this.announcer,
    required this.orchestrator,
    required this.audioBloc,
    required this.safetyBloc,
    required this.resourceBloc,
    required this.voiceAssistantBloc,
    required this.visionBloc,
    required this.sceneBloc,
    required this.hazardBloc,
    required this.smartReaderBloc,
    required this.objectMemoryBloc,
    required this.modelManagerBloc,
    required this.settingsBloc,
    required this.coordinator,
  });

  final OpenetraDatabase database;
  final AIModelRegistry registry;
  final DeviceResourceManager resourceManager;
  final VisionInferenceProvider visionProvider;
  final CameraSource cameraSource;
  final SpeechController speechController;
  final HapticFeedbackService hapticService;
  final AccessibilityAnnouncer announcer;
  final AIModelOrchestrator orchestrator;

  final AudioBloc audioBloc;
  final SafetyBloc safetyBloc;
  final DeviceResourceBloc resourceBloc;
  final VoiceAssistantBloc voiceAssistantBloc;
  final VisionBloc visionBloc;
  final SceneUnderstandingBloc sceneBloc;
  final HazardDetectionBloc hazardBloc;
  final SmartReaderBloc smartReaderBloc;
  final ObjectMemoryBloc objectMemoryBloc;
  final ModelManagerBloc modelManagerBloc;
  final SettingsBloc settingsBloc;
  final OpenetraCoordinator coordinator;

  static Future<OpenetraDependencies> bootstrap({
    required OpenetraDatabase database,
    VisionInferenceProvider? visionProvider,
    CameraSource? cameraSource,
    DeviceResourceManager? resourceManager,
    bool enablePlatformTts = true,
  }) async {
    final registry = AIModelRegistry();
    final resMgr = resourceManager ?? DeviceResourceManager();
    final vision = visionProvider ?? MirageInferenceProvider();
    final cam = cameraSource ?? CameraControllerBridge();
    final speech = SpeechController(
      resourceManager: resMgr,
      enablePlatformTts: enablePlatformTts,
    );
    final haptics = HapticFeedbackService();
    final announcer = AccessibilityAnnouncer(
      speechController: speech,
      hapticService: haptics,
    );
    final indicOcr = NativeIndicOcrProvider();
    final offlineAsr = NativeOfflineAsrProvider();
    final orchestrator = AIModelOrchestrator(
      registry: registry,
      resourceManager: resMgr,
      visionProvider: vision,
      indicOcrProviders: [indicOcr],
    );

    final audioBloc = AudioBloc(announcer: announcer, speechController: speech);
    final safetyBloc = SafetyBloc(database: database);
    final resourceBloc = DeviceResourceBloc(resourceManager: resMgr);
    final voiceBloc = VoiceAssistantBloc();
    final visionBloc = VisionBloc(orchestrator: orchestrator, cameraSource: cam);
    const sceneEngine = SceneUnderstandingEngine();
    final queryResolver = ContextualQueryResolver();
    final sceneBloc = SceneUnderstandingBloc(
      builder: (obs, prev, locale) {
        final desc = sceneEngine.build(obs, previousGraph: prev, locale: locale);
        queryResolver.recordGraph(desc.sceneGraph);
        return desc;
      },
      followUpResolver: (query, graph) =>
          queryResolver.answerFollowUp(query, fallbackGraph: graph),
    );
    final hazardEngine = HazardIntelligenceEngine();
    final hazardBloc = HazardDetectionBloc(
      evaluator: (obs, locale) => hazardEngine.evaluate(
        obs,
        deviceResourceDegraded: resMgr.currentState.isDegradedCapability,
        deviceDegradationReason: resMgr.currentState.degradationMessage,
        locale: locale,
      ),
      onReset: hazardEngine.reset,
    );
    final ocrRouter = OcrRouter(orchestrator: orchestrator);
    final readerBloc = SmartReaderBloc(
      reader: (obs, locale, frame) => ocrRouter.processObservation(
        mirageObservation: obs,
        targetLocale: locale,
        rawFrame: frame,
      ),
    );
    const safetyPolicy = OpenetraSafetyPolicy();
    final objectBloc = ObjectMemoryBloc(database: database);
    final modelBloc = ModelManagerBloc(
      registry: registry,
      visionProvider: vision,
      database: database,
    );
    final settingsBloc = SettingsBloc(database: database);

    final coordinator = OpenetraCoordinator(
      orchestrator: orchestrator,
      cameraSource: cam,
      database: database,
      voiceAssistantBloc: voiceBloc,
      sceneBloc: sceneBloc,
      hazardBloc: hazardBloc,
      smartReaderBloc: readerBloc,
      objectMemoryBloc: objectBloc,
      audioBloc: audioBloc,
      safetyBloc: safetyBloc,
      resourceBloc: resourceBloc,
      settingsBloc: settingsBloc,
      speechController: speech,
      offlineAsrProvider: offlineAsr,
      safetyOutputFilter: (r) => safetyPolicy.enforceResponse(r),
    );

    settingsBloc.add(const LoadSettings());
    objectBloc.add(const LoadPersonalObjects());
    safetyBloc.add(const LoadSafetyHistory());
    resourceBloc.add(const RefreshDeviceResources());

    return OpenetraDependencies(
      database: database,
      registry: registry,
      resourceManager: resMgr,
      visionProvider: vision,
      cameraSource: cam,
      speechController: speech,
      hapticService: haptics,
      announcer: announcer,
      orchestrator: orchestrator,
      audioBloc: audioBloc,
      safetyBloc: safetyBloc,
      resourceBloc: resourceBloc,
      voiceAssistantBloc: voiceBloc,
      visionBloc: visionBloc,
      sceneBloc: sceneBloc,
      hazardBloc: hazardBloc,
      smartReaderBloc: readerBloc,
      objectMemoryBloc: objectBloc,
      modelManagerBloc: modelBloc,
      settingsBloc: settingsBloc,
      coordinator: coordinator,
    );
  }
}

class OpenetraApp extends StatefulWidget {
  const OpenetraApp({
    super.key,
    required this.deps,
    this.skipOnboarding = false,
  });

  final OpenetraDependencies deps;
  final bool skipOnboarding;

  @override
  State<OpenetraApp> createState() => _OpenetraAppState();
}

class _OpenetraAppState extends State<OpenetraApp> {
  late bool _showHome;

  @override
  void initState() {
    super.initState();
    _showHome = widget.skipOnboarding ||
        widget.deps.settingsBloc.state.preferences.onboardingCompleted;
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: widget.deps.audioBloc),
        BlocProvider.value(value: widget.deps.safetyBloc),
        BlocProvider.value(value: widget.deps.resourceBloc),
        BlocProvider.value(value: widget.deps.voiceAssistantBloc),
        BlocProvider.value(value: widget.deps.visionBloc),
        BlocProvider.value(value: widget.deps.sceneBloc),
        BlocProvider.value(value: widget.deps.hazardBloc),
        BlocProvider.value(value: widget.deps.smartReaderBloc),
        BlocProvider.value(value: widget.deps.objectMemoryBloc),
        BlocProvider.value(value: widget.deps.modelManagerBloc),
        BlocProvider.value(value: widget.deps.settingsBloc),
      ],
      child: MaterialApp(
        title: 'Openetra',
        debugShowCheckedModeBanner: false,
        theme: OpenetraTheme.buildDarkTheme(),
        home: BlocListener<SettingsBloc, SettingsState>(
          listener: (context, state) {
            if (state.isLoaded &&
                state.preferences.onboardingCompleted &&
                !_showHome) {
              setState(() => _showHome = true);
            }
          },
          child: _showHome
              ? HomeScreen(coordinator: widget.deps.coordinator)
              : OnboardingScreen(
                  onCompleted: () => setState(() => _showHome = true),
                ),
        ),
      ),
    );
  }
}
