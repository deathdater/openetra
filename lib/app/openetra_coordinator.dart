import 'dart:async';
import 'package:uuid/uuid.dart';
import '../core/audio/bloc/audio_bloc.dart';
import '../core/audio/native_offline_asr_provider.dart';
import '../core/audio/speech_controller.dart';
import '../core/camera/camera_controller_bridge.dart';
import '../core/domain/entities/entities.dart';
import '../core/inference/ai_model_orchestrator.dart';
import '../core/inference/model_provider.dart';
import '../core/localization/openetra_localizer.dart';
import '../core/resource_management/bloc/device_resource_bloc.dart';
import '../core/safety/bloc/safety_bloc.dart';
import '../core/storage/openetra_database.dart';
import '../features/currency/domain/currency_recognition_service.dart';
import '../features/hazard_detection/bloc/hazard_detection_bloc.dart';
import '../features/object_memory/bloc/object_memory_bloc.dart';
import '../features/scene_understanding/bloc/scene_understanding_bloc.dart';
import '../features/settings/bloc/settings_bloc.dart';
import '../features/smart_reader/bloc/smart_reader_bloc.dart';
import '../features/voice_assistant/bloc/voice_assistant_bloc.dart';

/// Coordinates end-to-end offline user workflows A–E across BLoCs without
/// coupling UI screens to AI framework internals.
class OpenetraCoordinator {
  OpenetraCoordinator({
    required this.orchestrator,
    required this.cameraSource,
    required this.database,
    required this.voiceAssistantBloc,
    required this.sceneBloc,
    required this.hazardBloc,
    required this.smartReaderBloc,
    required this.objectMemoryBloc,
    required this.audioBloc,
    required this.safetyBloc,
    required this.resourceBloc,
    required this.settingsBloc,
    this.speechController,
    this.offlineAsrProvider,
    CurrencyRecognitionService? currencyService,
    AssistantResponse Function(AssistantResponse)? safetyOutputFilter,
  })  : _currencyService = currencyService ?? const CurrencyRecognitionService(),
        _safetyOutputFilter = safetyOutputFilter;

  final AIModelOrchestrator orchestrator;
  final CameraSource cameraSource;
  final OpenetraDatabase database;
  final VoiceAssistantBloc voiceAssistantBloc;
  final SceneUnderstandingBloc sceneBloc;
  final HazardDetectionBloc hazardBloc;
  final SmartReaderBloc smartReaderBloc;
  final ObjectMemoryBloc objectMemoryBloc;
  final AudioBloc audioBloc;
  final SafetyBloc safetyBloc;
  final DeviceResourceBloc resourceBloc;
  final SettingsBloc settingsBloc;
  final SpeechController? speechController;
  final NativeOfflineAsrProvider? offlineAsrProvider;

  final CurrencyRecognitionService _currencyService;
  AssistantResponse Function(AssistantResponse)? _safetyOutputFilter;
  static const _uuid = Uuid();

  VisionObservation? _lastObservation;
  bool _hazardLoopActive = false;

  bool get isHazardLoopActive => _hazardLoopActive;

  void attachSafetyFilter(
    AssistantResponse Function(AssistantResponse) filter,
  ) {
    _safetyOutputFilter = filter;
  }

  String get _activeLocale => settingsBloc.state.preferences.preferredLanguage;

  Future<void> _emitSpoken({
    required String spokenText,
    required String displaySummary,
    SpeechPriority priority = SpeechPriority.normal,
    HapticPattern haptic = HapticPattern.confirm,
    bool isDegraded = false,
    String? sourceObservationId,
  }) async {
    final raw = AssistantResponse(
      responseId: _uuid.v4(),
      spokenText: spokenText,
      displaySummary: displaySummary,
      locale: _activeLocale,
      priority: priority,
      hapticPattern: haptic,
      timestamp: DateTime.now(),
      isDegraded: isDegraded,
      sourceObservationId: sourceObservationId,
    );
    final safe = _safetyOutputFilter != null ? _safetyOutputFilter!(raw) : raw;
    if (safe.wasSafetySanitized) {
      safetyBloc.add(
        RecordSafetyEvent(
          SafetyEvent(
            eventId: _uuid.v4(),
            type: SafetyEventType.policySanitizedOutput,
            severity: HazardSeverity.caution,
            message: 'Sanitized outgoing response according to Openetra Safety Policy.',
            timestamp: DateTime.now(),
          ),
        ),
      );
    }
    voiceAssistantBloc.add(AssistantResponseDelivered(safe));
    audioBloc.add(SpeakAssistantResponse(safe));
    await database.logConversationTurn(
      id: _uuid.v4(),
      role: 'assistant',
      intent: voiceAssistantBloc.state.lastIntent?.type.name ?? 'action',
      utterance: safe.spokenText,
      language: _activeLocale,
    );
  }

  Future<CapturedFrame> _captureOrReuseFrame({CapturedFrame? overrideFrame}) async {
    if (overrideFrame != null) return overrideFrame;
    await cameraSource.start(
      minIntervalMs: resourceBloc.state.resourceState.inferenceIntervalMs,
    );
    return cameraSource.captureFrame();
  }

  /// Workflow A: Describe Surroundings
  Future<void> runDescribeSurroundings({CapturedFrame? overrideFrame}) async {
    try {
      await resourceBloc.resourceManager.refreshTelemetry();
      final frame = await _captureOrReuseFrame(overrideFrame: overrideFrame);
      final obs = await orchestrator.runVisualPerception(
        frame,
        task: ModelTask.scenePerception,
      );
      _lastObservation = obs;

      sceneBloc.add(ProcessSceneObservation(obs, locale: _activeLocale));
      hazardBloc.add(EvaluateHazardFrame(obs, locale: _activeLocale));

      // Wait briefly for synchronous bloc handlers in event queue.
      await Future<void>.delayed(Duration.zero);
      final desc = sceneBloc.state.latestDescription;
      final hazard = hazardBloc.state.latestAssessment;

      final buffer = StringBuffer();
      if (hazard != null &&
          (hazard.overallSeverity == HazardSeverity.critical ||
              hazard.overallSeverity == HazardSeverity.warning)) {
        buffer.write('${hazard.spokenAdvisory} ');
      }
      buffer.write(desc?.spokenSummary ?? 'Scene analyzed.');

      final degraded = obs.imageQuality.isDegraded ||
          resourceBloc.state.resourceState.isDegradedCapability;
      if (resourceBloc.state.resourceState.degradationMessage != null) {
        buffer.write(' ${resourceBloc.state.resourceState.degradationMessage}');
      }

      await _emitSpoken(
        spokenText: buffer.toString().trim(),
        displaySummary: desc?.spokenSummary ?? 'Scene description ready',
        priority: (hazard?.overallSeverity == HazardSeverity.critical)
            ? SpeechPriority.critical
            : SpeechPriority.normal,
        haptic: degraded
            ? HapticPattern.degraded
            : (hazard?.overallSeverity == HazardSeverity.critical
                ? HapticPattern.critical
                : HapticPattern.confirm),
        isDegraded: degraded,
        sourceObservationId: obs.provenance.observationId,
      );
    } catch (e) {
      await _emitSpoken(
        spokenText: 'Unable to describe surroundings right now: $e',
        displaySummary: 'Scene analysis error',
        priority: SpeechPriority.warning,
        haptic: HapticPattern.degraded,
        isDegraded: true,
      );
    }
  }

  /// Workflow B: Hazard Awareness (single scan or continuous loop toggle)
  Future<void> runHazardScan({CapturedFrame? overrideFrame}) async {
    try {
      resourceBloc.add(const ChangeOperatingMode(OperatingMode.hazardAwareness));
      final frame = await _captureOrReuseFrame(overrideFrame: overrideFrame);
      final obs = await orchestrator.runVisualPerception(
        frame,
        task: ModelTask.hazardSpecialist,
      );
      _lastObservation = obs;
      hazardBloc.add(EvaluateHazardFrame(obs, locale: _activeLocale));
      await Future<void>.delayed(Duration.zero);

      final assessment = hazardBloc.state.latestAssessment;
      final degraded = (assessment?.degradedModeActive ?? false) ||
          resourceBloc.state.resourceState.isDegradedCapability;
      final severity = assessment?.overallSeverity ?? HazardSeverity.info;

      final haptic = switch (severity) {
        HazardSeverity.critical => HapticPattern.critical,
        HazardSeverity.warning => HapticPattern.warning,
        HazardSeverity.caution => HapticPattern.caution,
        HazardSeverity.info =>
          degraded ? HapticPattern.degraded : HapticPattern.confirm,
      };
      final priority = (severity == HazardSeverity.critical ||
              severity == HazardSeverity.warning)
          ? SpeechPriority.critical
          : SpeechPriority.normal;

      if (degraded || severity == HazardSeverity.critical || severity == HazardSeverity.warning) {
        safetyBloc.add(
          RecordSafetyEvent(
            SafetyEvent(
              eventId: _uuid.v4(),
              type: degraded
                  ? SafetyEventType.degradedQuality
                  : SafetyEventType.hazardAlert,
              severity: severity,
              message: assessment?.spokenAdvisory ?? 'Hazard assessment recorded.',
              degradedReason: assessment?.degradationReasons.join(', '),
              timestamp: DateTime.now(),
            ),
          ),
        );
      }

      await _emitSpoken(
        spokenText: assessment?.spokenAdvisory ??
            'No obvious hazards detected in the camera view; proceed using your white cane.',
        displaySummary: assessment?.spokenAdvisory ?? 'Hazard scan completed',
        priority: priority,
        haptic: haptic,
        isDegraded: degraded,
        sourceObservationId: obs.provenance.observationId,
      );
    } catch (e) {
      await _emitSpoken(
        spokenText:
            'Hazard scan unavailable right now ($e). Rely on your white cane and proceed carefully.',
        displaySummary: 'Hazard scan degraded',
        priority: SpeechPriority.warning,
        haptic: HapticPattern.degraded,
        isDegraded: true,
      );
    }
  }

  /// Toggles continuous hazard scanning respecting DeviceResourceManager cadence.
  Future<void> toggleContinuousHazardAwareness() async {
    if (_hazardLoopActive) {
      _hazardLoopActive = false;
      hazardBloc.add(const ResetHazardTracker());
      await cameraSource.stop();
      await _emitSpoken(
        spokenText: 'Hazard awareness paused.',
        displaySummary: 'Hazard mode paused',
      );
      return;
    }

    _hazardLoopActive = true;
    await _emitSpoken(
      spokenText:
          'Hazard awareness active. Point camera ahead and slightly downward. Continue using your white cane.',
      displaySummary: 'Hazard mode active',
      haptic: HapticPattern.caution,
    );

    unawaited(Future<void>(() async {
      while (_hazardLoopActive) {
        await runHazardScan();
        final interval = resourceBloc.state.resourceState.inferenceIntervalMs;
        await Future<void>.delayed(
          Duration(milliseconds: interval > 300 ? interval : 600),
        );
      }
    }));
  }

  /// Workflow C: Read Text (Latin + Indic script routing)
  Future<void> runSmartReader({CapturedFrame? overrideFrame}) async {
    try {
      resourceBloc.add(const ChangeOperatingMode(OperatingMode.reading));
      final frame = await _captureOrReuseFrame(overrideFrame: overrideFrame);
      final obs = await orchestrator.runVisualPerception(
        frame,
        task: ModelTask.latinOcr,
      );
      _lastObservation = obs;
      smartReaderBloc.add(
        ReadObservedText(
          observation: obs,
          targetLocale: _activeLocale,
          frame: frame,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final result = smartReaderBloc.state.latestResult;
      if (result == null || result.isEmpty) {
        final note = result?.missingPackNotice;
        await _emitSpoken(
          spokenText: note ??
              'No readable text detected clearly. Hold the page steady about 30 centimeters from the camera.',
          displaySummary: 'No text detected',
          haptic: HapticPattern.caution,
        );
        return;
      }

      await database.saveScannedDocument(
        id: _uuid.v4(),
        title: 'Scan ${DateTime.now().toIso8601String()}',
        script: result.detectedScript,
        extractedText: result.fullText,
        confidence: result.provenance.confidence,
        language: _activeLocale,
      );

      final extraNotice =
          result.missingPackNotice != null ? ' ${result.missingPackNotice}' : '';
      await _emitSpoken(
        spokenText: '${result.fullText}$extraNotice',
        displaySummary: result.fullText,
        sourceObservationId: obs.provenance.observationId,
      );
    } catch (e) {
      await _emitSpoken(
        spokenText: 'Unable to read text right now: $e',
        displaySummary: 'Text reading failed',
        priority: SpeechPriority.warning,
        haptic: HapticPattern.degraded,
        isDegraded: true,
      );
    }
  }

  /// Workflow D: Find Personal Belongings
  Future<void> runFindObject(
    String itemName, {
    CapturedFrame? overrideFrame,
  }) async {
    try {
      resourceBloc.add(const ChangeOperatingMode(OperatingMode.objectSearch));
      final frame = await _captureOrReuseFrame(overrideFrame: overrideFrame);
      final obs = await orchestrator.runVisualPerception(
        frame,
        task: ModelTask.scenePerception,
        overrideProfile: MirageQueryProfile.objectSearch,
        keywords: [itemName],
      );
      _lastObservation = obs;
      objectMemoryBloc.add(FindPersonalObject(itemName, observation: obs));
      await Future<void>.delayed(Duration.zero);

      final msg = objectMemoryBloc.state.lastSearchResult ??
          'Searched camera view for $itemName.';
      await _emitSpoken(
        spokenText: msg,
        displaySummary: msg,
        sourceObservationId: obs.provenance.observationId,
      );
    } catch (e) {
      await _emitSpoken(
        spokenText: 'Object search failed: $e',
        displaySummary: 'Object search error',
        haptic: HapticPattern.degraded,
        isDegraded: true,
      );
    }
  }

  /// Workflow E: Indian Currency Recognition
  Future<void> runIdentifyCurrency({CapturedFrame? overrideFrame}) async {
    try {
      final frame = await _captureOrReuseFrame(overrideFrame: overrideFrame);
      final obs = await orchestrator.runVisualPerception(
        frame,
        task: ModelTask.latinOcr,
        overrideProfile: MirageQueryProfile.latinOcr,
      );
      _lastObservation = obs;
      final res = await _currencyService.identify(
        frame: frame,
        mirageObservation: obs,
        locale: _activeLocale,
      );
      await _emitSpoken(
        spokenText: res.spokenAdvisory,
        displaySummary: res.spokenAdvisory,
        haptic: res.isUncertain ? HapticPattern.caution : HapticPattern.confirm,
        isDegraded: frame.qualityMetrics.isDegraded,
        sourceObservationId: res.provenance.observationId,
      );
    } catch (e) {
      await _emitSpoken(
        spokenText:
            'Could not analyze currency note ($e). ${CurrencyRecognitionService.nonCounterfeitDisclaimer}',
        displaySummary: 'Currency scan error',
        haptic: HapticPattern.degraded,
        isDegraded: true,
      );
    }
  }

  /// Routes a recognized or typed offline voice command.
  Future<void> handleVoiceCommand(String transcript) async {
    voiceAssistantBloc.add(SubmitVoiceTranscript(transcript));
    await Future<void>.delayed(Duration.zero);
    final intent = voiceAssistantBloc.state.lastIntent;
    if (intent == null) return;

    await database.logConversationTurn(
      id: _uuid.v4(),
      role: 'user',
      intent: intent.type.name,
      utterance: transcript,
      language: _activeLocale,
    );

    switch (intent.type) {
      case VoiceIntentType.stopSpeaking:
        _hazardLoopActive = false;
        audioBloc.add(const InterruptSpeechRequested());
        return;
      case VoiceIntentType.repeatLast:
        audioBloc.add(const RepeatSpeechRequested());
        return;
      case VoiceIntentType.describeSurroundings:
        await runDescribeSurroundings();
        return;
      case VoiceIntentType.lookForHazards:
        await runHazardScan();
        return;
      case VoiceIntentType.readText:
        await runSmartReader();
        return;
      case VoiceIntentType.identifyCurrency:
        await runIdentifyCurrency();
        return;
      case VoiceIntentType.findObject:
        await runFindObject(intent.targetArgument ?? 'wallet');
        return;
      case VoiceIntentType.followUpQuery:
        sceneBloc.add(AnswerSceneFollowUp(intent.rawTranscript));
        await Future<void>.delayed(Duration.zero);
        final answer = sceneBloc.state.followUpAnswer ??
            'No fresh scene is loaded yet. Tap Describe Surroundings first.';
        await _emitSpoken(spokenText: answer, displaySummary: answer);
        return;
      case VoiceIntentType.switchMode:
        final arg = intent.targetArgument ?? '';
        final mode = arg.contains('eco')
            ? OperatingMode.eco
            : (arg.contains('hazard')
                ? OperatingMode.hazardAwareness
                : OperatingMode.balanced);
        resourceBloc.add(ChangeOperatingMode(mode));
        await _emitSpoken(
          spokenText: 'Switched to ${mode.name} operating mode.',
          displaySummary: 'Mode: ${mode.name}',
        );
        return;
      case VoiceIntentType.switchLanguage:
        final arg = intent.targetArgument ?? '';
        final nextLocale = arg.contains('hindi')
            ? 'hi-IN'
            : (arg.contains('kannada') ? 'kn-IN' : 'en-IN');
        settingsBloc.add(UpdatePreferredLanguage(nextLocale));
        audioBloc.add(UpdateSpeechConfig(locale: nextLocale));
        await _emitSpoken(
          spokenText: 'Language switched to $nextLocale.',
          displaySummary: 'Language: $nextLocale',
        );
        return;
      case VoiceIntentType.openSettings:
      case VoiceIntentType.unknown:
        await _emitSpoken(
          spokenText:
              'I did not match that command. Say describe surroundings, look for hazards, read this, identify note, or find my wallet.',
          displaySummary: 'Unrecognized voice command',
          haptic: HapticPattern.caution,
        );
    }
  }

  /// Triggers offline microphone capture gated against Openetra's own TTS.
  Future<void> listenForOfflineVoiceCommand() async {
    if (speechController?.shouldGateMicrophone == true ||
        audioBloc.state.isSpeaking) {
      await _emitSpoken(
        spokenText: OpenetraLocalizer.micGatedNotice(_activeLocale),
        displaySummary: 'Microphone gated during speech',
        haptic: HapticPattern.caution,
      );
      return;
    }

    final asr = offlineAsrProvider;
    if (asr == null) {
      await _emitSpoken(
        spokenText:
            'Offline speech recognizer is unavailable; use the command text field or primary buttons.',
        displaySummary: 'Offline ASR unavailable',
        haptic: HapticPattern.caution,
      );
      return;
    }

    try {
      final result = await asr.recordAndRecognizeOffline(locale: _activeLocale);
      if (result.transcript.trim().isEmpty) {
        await _emitSpoken(
          spokenText: 'No speech detected. Please speak clearly after the tone.',
          displaySummary: 'No speech detected',
          haptic: HapticPattern.caution,
        );
        return;
      }
      await handleVoiceCommand(result.transcript);
    } catch (e) {
      await _emitSpoken(
        spokenText:
            'Offline voice pack is not installed for $_activeLocale ($e). Type a command or select a workflow button.',
        displaySummary: 'Offline voice pack unavailable',
        haptic: HapticPattern.caution,
        isDegraded: true,
      );
    }
  }

  VisionObservation? get lastObservation => _lastObservation;
}
