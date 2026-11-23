import 'dart:async';
import '../domain/entities/entities.dart';
import '../errors/openetra_failure.dart';
import '../resource_management/device_resource_manager.dart';
import 'ai_model_registry.dart';
import 'model_provider.dart';

/// Central task-based AI orchestrator enforcing lazy loading, single-flight
/// execution, operating-mode selective profiles, and benchmark telemetry.
class AIModelOrchestrator {
  AIModelOrchestrator({
    required this.registry,
    required this.resourceManager,
    required this.visionProvider,
    this.indicOcrProviders = const [],
    this.currencyClassifier,
    this.depthProvider,
    this.embeddingProvider,
  });

  final AIModelRegistry registry;
  final DeviceResourceManager resourceManager;
  final VisionInferenceProvider visionProvider;
  final List<OcrProvider> indicOcrProviders;
  final CurrencyClassifierProvider? currencyClassifier;
  final DepthProvider? depthProvider;
  final EmbeddingProvider? embeddingProvider;

  Future<void> _serialQueue = Future<void>.value();

  /// Serializes native model invocations so global engine state never races.
  Future<T> _runSerialized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    _serialQueue = _serialQueue.then((_) async {
      try {
        final result = await action();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }

  MirageQueryProfile profileForTask(ModelTask task, OperatingMode mode) {
    switch (task) {
      case ModelTask.latinOcr:
        return MirageQueryProfile.latinOcr;
      case ModelTask.hazardSpecialist:
        return MirageQueryProfile.hazardScan;
      case ModelTask.scenePerception:
        if (mode == OperatingMode.eco) return MirageQueryProfile.sceneEco;
        if (mode == OperatingMode.objectSearch) {
          return MirageQueryProfile.objectSearch;
        }
        if (mode == OperatingMode.hazardAwareness) {
          return MirageQueryProfile.hazardScan;
        }
        return MirageQueryProfile.sceneBalanced;
      default:
        return MirageQueryProfile.sceneBalanced;
    }
  }

  Future<void> ensureVisionLoaded() async {
    if (visionProvider.isLoaded) return;
    final state = resourceManager.currentState;
    final loadPerf =
        await visionProvider.load(threads: state.recommendedThreads);
    registry.recordPerformance(loadPerf);
    final meta = registry.getById(visionProvider.modelId);
    if (meta != null) {
      registry.updateModel(meta.copyWith(status: ModelStatus.loadedInMemory));
    }
  }

  Future<void> releaseIdleModels() async {
    if (visionProvider.isLoaded) {
      await visionProvider.unload();
      final meta = registry.getById(visionProvider.modelId);
      if (meta != null) {
        registry.updateModel(meta.copyWith(status: ModelStatus.verifiedReady));
      }
    }
  }

  /// Runs Mirage visual perception with task-specific selective options.
  Future<VisionObservation> runVisualPerception(
    CapturedFrame frame, {
    ModelTask task = ModelTask.scenePerception,
    MirageQueryProfile? overrideProfile,
    List<String>? keywords,
  }) {
    return _runSerialized(() async {
      final resourceState = resourceManager.currentState;
      if (resourceState.thermalState == ThermalState.critical) {
        throw const ThermalThrottleFailure(
          'Device temperature is critical; pausing AI vision inference to cool down.',
        );
      }
      await ensureVisionLoaded();
      final profile =
          overrideProfile ?? profileForTask(task, resourceState.operatingMode);
      final obs = await visionProvider.analyze(
        frame,
        profile: profile,
        keywords: keywords,
      );
      registry.recordPerformance(
        ModelPerformance(
          modelId: obs.provenance.modelId,
          measuredLatencyMs: obs.provenance.processingDurationMs,
          coldLoadMs: 0,
          inputWidth: obs.provenance.inputWidth,
          inputHeight: obs.provenance.inputHeight,
          deviceTier: 'android-runtime',
          recordedAt: DateTime.now(),
        ),
      );
      return obs;
    });
  }

  /// Selects the appropriate OCR provider for [script] following Section 6.1 routing.
  Future<OcrProvider?> selectOcrProvider(DetectedScript script) async {
    if (script == DetectedScript.latin || script == DetectedScript.unknown) {
      return null; // Handled directly by Mirage Latin OCR.
    }
    for (final provider in indicOcrProviders) {
      if (provider.supportedScripts.contains(script) &&
          await provider.isPackInstalled(script)) {
        return provider;
      }
    }
    return null;
  }
}
