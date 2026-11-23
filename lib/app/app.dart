import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/accessibility/accessibility_announcer.dart';
import '../core/assistive/assistive_action.dart';
import '../core/assistive/assistive_action_router.dart';
import '../core/assistive/audio_arbitrator.dart';
import '../core/assistive/camera_resource_manager.dart';
import '../core/assistive/feedback_dispatcher.dart';
import '../core/assistive/permission_coordinator.dart';
import '../core/assistive/task_orchestrator.dart';
import '../core/audio/bloc/audio_bloc.dart';
import '../core/audio/haptic_feedback_service.dart';
import '../core/haptics/haptic_feedback_manager.dart';
import '../core/audio/native_offline_asr_provider.dart';
import '../core/audio/speech_controller.dart';
import '../core/camera/camera_controller_bridge.dart';
import '../core/inference/ai_model_orchestrator.dart';
import '../core/inference/ai_model_registry.dart';
import '../core/inference/mirage/mirage_inference_provider.dart';
import '../core/inference/model_provider.dart';
import '../core/inference/specialist/native_specialist_providers.dart';
import '../core/resource_management/bloc/device_resource_bloc.dart';
import '../core/resource_management/device_resource_manager.dart';
import '../core/safety/bloc/safety_bloc.dart';
import '../core/safety/openetra_safety_policy.dart';
import '../core/storage/openetra_database.dart';
import '../features/currency/domain/currency_recognition_service.dart';
import '../features/dial/bloc/assistive_dial_bloc.dart';
import '../features/dial/presentation/pages/assistive_dial_page.dart';
import '../features/emergency/bloc/emergency_bloc.dart';
import '../features/emergency/data/protected_contact_store.dart';
import '../features/emergency/domain/emergency_assistance_service.dart';
import '../features/flashlight/data/native_flashlight_gateway.dart';
import '../features/flashlight/domain/intelligent_flashlight_controller.dart';
import '../features/floating_companion/bloc/floating_companion_bloc.dart';
import '../features/floating_companion/data/native_floating_companion_bridge.dart';
import '../features/gestures/bloc/gesture_automation_bloc.dart';
import '../features/gestures/data/native_gesture_gateway.dart';
import '../features/hazard_detection/bloc/hazard_detection_bloc.dart';
import '../features/hazard_detection/domain/hazard_intelligence_engine.dart';
import '../features/model_manager/bloc/model_manager_bloc.dart';
import '../features/object_memory/bloc/object_memory_bloc.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/scene_understanding/bloc/scene_understanding_bloc.dart';
import '../features/scene_understanding/domain/contextual_query_resolver.dart';
import '../features/scene_understanding/domain/scene_understanding_engine.dart';
import '../features/settings/bloc/settings_bloc.dart';
import '../features/shopping/data/sqlite_product_catalog.dart';
import '../features/shopping/domain/shopping_assistant_service.dart';
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
    required this.permissionCoordinator,
    required this.cameraResourceManager,
    required this.audioArbitrator,
    required this.actionRouter,
    required this.taskOrchestrator,
    required this.feedbackDispatcher,
    required this.emergencyBloc,
    required this.flashlightController,
    required this.gestureBloc,
    required this.floatingCompanionBloc,
    required this.hapticManager,
    required this.dialBloc,
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
  final PermissionCoordinator permissionCoordinator;
  final CameraResourceManager cameraResourceManager;
  final AudioArbitrator audioArbitrator;
  final AssistiveActionRouter actionRouter;
  final TaskOrchestrator taskOrchestrator;
  final FeedbackDispatcher feedbackDispatcher;
  final EmergencyBloc emergencyBloc;
  final IntelligentFlashlightController flashlightController;
  final GestureAutomationBloc gestureBloc;
  final FloatingCompanionBloc floatingCompanionBloc;
  final HapticFeedbackManager hapticManager;
  final AssistiveDialBloc dialBloc;

  static Future<OpenetraDependencies> bootstrap({
    required OpenetraDatabase database,
    VisionInferenceProvider? visionProvider,
    CameraSource? cameraSource,
    DeviceResourceManager? resourceManager,
    ProtectedContactStore? contactStore,
    FlashlightGateway? flashlightGateway,
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
    final embeddingProvider = NativeEmbeddingProvider();
    final currencyClassifier = NativeCurrencyClassifierProvider();
    final barcodeScanner = NativeBarcodeScannerProvider();
    final orchestrator = AIModelOrchestrator(
      registry: registry,
      resourceManager: resMgr,
      visionProvider: vision,
      indicOcrProviders: [indicOcr],
      currencyClassifier: currencyClassifier,
      embeddingProvider: embeddingProvider,
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
    final objectBloc = ObjectMemoryBloc(
      database: database,
      embeddingProvider: embeddingProvider,
    );
    final modelBloc = ModelManagerBloc(
      registry: registry,
      visionProvider: vision,
      database: database,
    );
    final emergencyService = EmergencyAssistanceService(
      store: contactStore ?? NativeEncryptedContactStore(),
      database: database,
    );
    final emergencyBloc = EmergencyBloc(service: emergencyService);
    final settingsBloc = SettingsBloc(
      database: database,
      onClearProtectedStorage: () async {
        await emergencyService.clearAllContacts();
        emergencyBloc.add(const LoadEmergencyConfig());
      },
    );
    final shoppingService = ShoppingAssistantService(
      catalogLookup: SqliteProductCatalogLookup(database),
    );
    final currencyService = CurrencyRecognitionService(
      classifier: currencyClassifier,
    );
    final permissionCoordinator = PermissionCoordinator();
    final cameraResourceManager = CameraResourceManager(cameraSource: cam);
    final audioArbitrator = AudioArbitrator(
      audioBloc: audioBloc,
      speechController: speech,
    );
    final flashlightController = IntelligentFlashlightController(
      gateway: flashlightGateway ?? NativeFlashlightGateway(),
      resourceManager: resMgr,
      cameraResourceManager: cameraResourceManager,
      audioArbitrator: audioArbitrator,
      database: database,
    );
    final actionRouter = AssistiveActionRouter();
    final availabilityService = CapabilityAvailabilityService(
      permissions: permissionCoordinator,
    );
    final taskOrchestrator = TaskOrchestrator(
      router: actionRouter,
      availabilityService: availabilityService,
    );
    final floatingBridge = NativeFloatingCompanionBridge();
    final feedbackDispatcher = FeedbackDispatcher(
      orchestrator: taskOrchestrator,
      audioBloc: audioBloc,
    )
      ..attachOverlaySink(floatingBridge)
      ..start();
    final floatingCompanionBloc = FloatingCompanionBloc(
      bridge: floatingBridge,
      taskOrchestrator: taskOrchestrator,
      database: database,
    );
    final gestureBloc = GestureAutomationBloc(
      gateway: NativeGestureGateway(),
      taskOrchestrator: taskOrchestrator,
      cameraResourceManager: cameraResourceManager,
      database: database,
    );

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
      barcodeScanner: barcodeScanner,
      permissionCoordinator: permissionCoordinator,
      cameraResourceManager: cameraResourceManager,
      audioArbitrator: audioArbitrator,
      actionRouter: actionRouter,
      taskOrchestrator: taskOrchestrator,
      emergencyBloc: emergencyBloc,
      flashlightController: flashlightController,
      gestureBloc: gestureBloc,
      floatingCompanionBloc: floatingCompanionBloc,
      shoppingService: shoppingService,
      currencyService: currencyService,
      safetyOutputFilter: (r) => safetyPolicy.enforceResponse(r),
    );

    _registerDefaultAssistiveActions(
      router: actionRouter,
      coordinator: coordinator,
      emergencyBloc: emergencyBloc,
      flashlightController: flashlightController,
      audioBloc: audioBloc,
    );

    final hapticManager = HapticFeedbackManager(service: haptics);
    final dialBloc = AssistiveDialBloc(
      taskOrchestrator: taskOrchestrator,
      audioArbitrator: audioArbitrator,
      hapticManager: hapticManager,
      onFlashlightExplicit: (on) async {
        await flashlightController.setManualTorch(on);
      },
      onToggleContinuousHazard: coordinator.toggleContinuousHazardAwareness,
    );

    settingsBloc.add(const LoadSettings());
    objectBloc.add(const LoadPersonalObjects());
    safetyBloc.add(const LoadSafetyHistory());
    resourceBloc.add(const RefreshDeviceResources());
    emergencyBloc.add(const LoadEmergencyConfig());
    gestureBloc.add(const LoadGestureConfig());
    floatingCompanionBloc.add(const LoadFloatingCompanionConfig());
    await flashlightController.initialize();

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
      permissionCoordinator: permissionCoordinator,
      cameraResourceManager: cameraResourceManager,
      audioArbitrator: audioArbitrator,
      actionRouter: actionRouter,
      taskOrchestrator: taskOrchestrator,
      feedbackDispatcher: feedbackDispatcher,
      emergencyBloc: emergencyBloc,
      flashlightController: flashlightController,
      gestureBloc: gestureBloc,
      floatingCompanionBloc: floatingCompanionBloc,
      hapticManager: hapticManager,
      dialBloc: dialBloc,
    );
  }

  static void _registerDefaultAssistiveActions({
    required AssistiveActionRouter router,
    required OpenetraCoordinator coordinator,
    required EmergencyBloc emergencyBloc,
    required IntelligentFlashlightController flashlightController,
    required AudioBloc audioBloc,
  }) {
    router.register(
      spec: const AssistiveActionSpec(
        id: AssistiveActionId.describeScene,
        displayName: 'Describe Scene',
        accessibleDescription: 'Captures camera view and describes surroundings',
        backgroundCategory: BackgroundExecutionCategory.foregroundUiRequired,
        requiresCamera: true,
      ),
      handler: (_) => coordinator.runDescribeSurroundings(),
    );
    router.register(
      spec: const AssistiveActionSpec(
        id: AssistiveActionId.readText,
        displayName: 'Read Text',
        accessibleDescription: 'Reads visible text using offline Latin or Indic OCR',
        backgroundCategory: BackgroundExecutionCategory.foregroundUiRequired,
        requiresCamera: true,
      ),
      handler: (_) => coordinator.runSmartReader(),
    );
    router.register(
      spec: const AssistiveActionSpec(
        id: AssistiveActionId.assessHazardCues,
        displayName: 'Hazard Scan',
        accessibleDescription: 'Checks camera view for potential hazards with uncertainty notice',
        backgroundCategory: BackgroundExecutionCategory.foregroundUiRequired,
        requiresCamera: true,
      ),
      handler: (_) => coordinator.runHazardScan(),
    );
    router.register(
      spec: const AssistiveActionSpec(
        id: AssistiveActionId.findRegisteredObject,
        displayName: 'Find Registered Object',
        accessibleDescription: 'Searches camera view for a saved personal item',
        backgroundCategory: BackgroundExecutionCategory.foregroundUiRequired,
        requiresCamera: true,
        supportsParameter: true,
      ),
      handler: (ctx) => coordinator.runFindObject(ctx.argument ?? 'wallet'),
    );
    router.register(
      spec: const AssistiveActionSpec(
        id: AssistiveActionId.identifyCurrency,
        displayName: 'Identify Currency',
        accessibleDescription: 'Checks Indian rupee denomination with non-counterfeit notice',
        backgroundCategory: BackgroundExecutionCategory.foregroundUiRequired,
        requiresCamera: true,
      ),
      handler: (_) => coordinator.runIdentifyCurrency(),
    );
    router.register(
      spec: const AssistiveActionSpec(
        id: AssistiveActionId.scanProduct,
        displayName: 'Scan Product',
        accessibleDescription: 'Reads barcode or packaging offline',
        backgroundCategory: BackgroundExecutionCategory.foregroundUiRequired,
        requiresCamera: true,
      ),
      handler: (_) => coordinator.runScanProduct(),
    );
    router.register(
      spec: const AssistiveActionSpec(
        id: AssistiveActionId.startEmergencyAssistance,
        displayName: 'Emergency Assistance',
        accessibleDescription: 'Opens confirmed emergency contact flow and phone dialer',
        backgroundCategory: BackgroundExecutionCategory.backgroundSafe,
        requiresConfirmation: true,
        preemptsActiveTask: true,
        redactAuditArguments: true,
      ),
      handler: (_) async {
        emergencyBloc.add(const RequestEmergencyInitiation());
      },
    );
    router.register(
      spec: const AssistiveActionSpec(
        id: AssistiveActionId.toggleFlashlight,
        displayName: 'Toggle Flashlight',
        accessibleDescription: 'Toggles phone flashlight with ownership protection',
        backgroundCategory: BackgroundExecutionCategory.backgroundSafe,
        requiresTorch: true,
      ),
      handler: (_) async {
        await flashlightController.toggleManual();
      },
    );
    router.register(
      spec: const AssistiveActionSpec(
        id: AssistiveActionId.cancelActiveTask,
        displayName: 'Cancel Active Task',
        accessibleDescription: 'Stops active speech, camera, and assistive task',
        backgroundCategory: BackgroundExecutionCategory.backgroundSafe,
        preemptsActiveTask: true,
      ),
      handler: (_) => coordinator.stopAll(),
    );
    router.register(
      spec: const AssistiveActionSpec(
        id: AssistiveActionId.repeatLast,
        displayName: 'Repeat Last Response',
        accessibleDescription: 'Speaks the last Openetra announcement again',
        backgroundCategory: BackgroundExecutionCategory.backgroundSafe,
      ),
      handler: (_) async {
        audioBloc.add(const RepeatSpeechRequested());
      },
    );
  }
}

class OpenetraApp extends StatefulWidget {
  const OpenetraApp({
    super.key,
    required this.deps,
    this.skipOnboarding = false,
    this.useClassicHome = false,
  });

  final OpenetraDependencies deps;
  final bool skipOnboarding;
  final bool useClassicHome;

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
        BlocProvider.value(value: widget.deps.emergencyBloc),
        BlocProvider.value(value: widget.deps.gestureBloc),
        BlocProvider.value(value: widget.deps.floatingCompanionBloc),
        BlocProvider.value(value: widget.deps.dialBloc),
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
              ? (widget.useClassicHome
                  ? HomeScreen(coordinator: widget.deps.coordinator)
                  : AssistiveDialPage(coordinator: widget.deps.coordinator))
              : OnboardingScreen(
                  onCompleted: () => setState(() => _showHome = true),
                ),
        ),
      ),
    );
  }
}
