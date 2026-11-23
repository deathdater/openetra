import 'package:flutter_test/flutter_test.dart';
import 'package:openetra/core/domain/entities/entities.dart';
import 'package:openetra/core/errors/openetra_failure.dart';
import 'package:openetra/core/inference/ai_model_orchestrator.dart';
import 'package:openetra/core/inference/ai_model_registry.dart';
import 'package:openetra/core/inference/model_provider.dart';
import 'package:openetra/core/resource_management/device_resource_manager.dart';

class _RecordingVisionProvider implements VisionInferenceProvider {
  bool loaded = false;
  int concurrentCalls = 0;
  int maxConcurrentObserved = 0;
  final List<MirageQueryProfile> profilesSeen = [];

  @override
  String get modelId => AIModelRegistry.mirageId;

  @override
  bool get isLoaded => loaded;

  @override
  Future<ModelPerformance> load({int threads = 0}) async {
    loaded = true;
    return ModelPerformance(
      modelId: modelId,
      measuredLatencyMs: 0,
      coldLoadMs: 22,
      inputWidth: 0,
      inputHeight: 0,
      deviceTier: 'test',
      recordedAt: DateTime(2026, 11, 23),
    );
  }

  @override
  Future<void> unload() async {
    loaded = false;
  }

  @override
  Future<VisionObservation> analyze(
    CapturedFrame frame, {
    required MirageQueryProfile profile,
    List<String>? keywords,
  }) async {
    concurrentCalls++;
    if (concurrentCalls > maxConcurrentObserved) {
      maxConcurrentObserved = concurrentCalls;
    }
    profilesSeen.add(profile);
    await Future<void>.delayed(const Duration(milliseconds: 15));
    concurrentCalls--;

    return VisionObservation(
      provenance: ObservationProvenance(
        observationId: 'obs-rec',
        timestamp: DateTime(2026, 11, 23),
        modelId: modelId,
        modelVersion: '4.1.4',
        confidence: 0.7,
        inputWidth: frame.width,
        inputHeight: frame.height,
        processingDurationMs: 15,
        sourceCapability: 'mirage_describe',
        validationStatus: ValidationStatus.verified,
      ),
      imageQuality: frame.qualityMetrics,
    );
  }
}

void main() {
  test('orchestrator selects mode-appropriate profiles, lazy loads, serializes calls, and unloads cleanly', () async {
    final registry = AIModelRegistry();
    final resMgr = DeviceResourceManager();
    final vision = _RecordingVisionProvider();
    final orchestrator = AIModelOrchestrator(
      registry: registry,
      resourceManager: resMgr,
      visionProvider: vision,
    );

    expect(vision.isLoaded, isFalse);

    resMgr.setOperatingMode(OperatingMode.eco);
    final frame = CapturedFrame(
      width: 640,
      height: 480,
      capturedAt: DateTime(2026, 11, 23),
      qualityMetrics: ImageQualityMetrics.nominal,
    );

    await Future.wait([
      orchestrator.runVisualPerception(frame, task: ModelTask.scenePerception),
      orchestrator.runVisualPerception(frame, task: ModelTask.latinOcr),
    ]);

    expect(vision.isLoaded, isTrue);
    expect(vision.maxConcurrentObserved, 1);
    expect(vision.profilesSeen[0].sections, ['scene', 'objects']);
    expect(vision.profilesSeen[0].fields, isNot(contains('mask')));
    expect(vision.profilesSeen[1].sections, ['text']);
    expect(registry.getById(AIModelRegistry.mirageId)?.status, ModelStatus.loadedInMemory);

    await orchestrator.releaseIdleModels();
    expect(vision.isLoaded, isFalse);
    expect(registry.getById(AIModelRegistry.mirageId)?.status, ModelStatus.verifiedReady);
  });

  test('blocks inference under critical thermal state and reports honest hazard degradation', () async {
    final resMgr = DeviceResourceManager();
    final vision = _RecordingVisionProvider();
    final orchestrator = AIModelOrchestrator(
      registry: AIModelRegistry(),
      resourceManager: resMgr,
      visionProvider: vision,
    );

    final hotState = resMgr.applySimulatedTelemetry(
      mode: OperatingMode.hazardAwareness,
      thermalState: ThermalState.severe,
      batteryPercent: 12,
      isCharging: false,
    );
    expect(hotState.isDegradedCapability, isTrue);
    expect(hotState.degradationMessage, isNotNull);
    expect(hotState.recommendedThreads, 2);

    resMgr.applySimulatedTelemetry(thermalState: ThermalState.critical);
    final frame = CapturedFrame(
      width: 640,
      height: 480,
      capturedAt: DateTime(2026, 11, 23),
      qualityMetrics: ImageQualityMetrics.nominal,
    );
    await expectLater(
      () => orchestrator.runVisualPerception(frame),
      throwsA(isA<ThermalThrottleFailure>()),
    );
  });
}
