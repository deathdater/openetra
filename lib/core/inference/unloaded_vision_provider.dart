import 'package:uuid/uuid.dart';
import '../domain/entities/entities.dart';
import '../errors/openetra_failure.dart';
import 'ai_model_registry.dart';
import 'model_provider.dart';

/// Phase 1 baseline provider used only before Phase 2 binds the real Cactus
/// Mirage C++ JNI bridge in MirageInferenceProvider.
class UnloadedVisionProvider implements VisionInferenceProvider {
  bool _loaded = false;
  static const _uuid = Uuid();

  @override
  String get modelId => AIModelRegistry.mirageId;

  @override
  bool get isLoaded => _loaded;

  @override
  Future<ModelPerformance> load({int threads = 0}) async {
    _loaded = false;
    throw const ModelNotLoadedFailure(
      'Native Mirage runtime is not yet bound in this build.',
    );
  }

  @override
  Future<void> unload() async {
    _loaded = false;
  }

  @override
  Future<VisionObservation> analyze(
    CapturedFrame frame, {
    required MirageQueryProfile profile,
    List<String>? keywords,
  }) async {
    return VisionObservation(
      provenance: ObservationProvenance(
        observationId: _uuid.v4(),
        timestamp: DateTime.now(),
        modelId: modelId,
        modelVersion: 'unloaded',
        confidence: 0.0,
        inputWidth: frame.width,
        inputHeight: frame.height,
        processingDurationMs: 0,
        sourceCapability: 'unloaded',
        validationStatus: ValidationStatus.unavailable,
      ),
      imageQuality: frame.qualityMetrics,
    );
  }
}
