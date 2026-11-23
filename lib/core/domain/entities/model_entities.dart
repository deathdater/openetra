import 'package:equatable/equatable.dart';

enum ModelTask {
  scenePerception,
  latinOcr,
  indicOcr,
  indianAsr,
  offlineTts,
  currencyClassification,
  depthEstimation,
  objectEmbedding,
  barcodeLookup,
  hazardSpecialist,
  vad,
  handGesture,
}

enum ModelRuntime {
  cactusNative,
  androidSystemTts,
  sherpaOnnx,
  liteRtTflite,
  onnxRuntime,
  tesseractNative,
  mlKitOffline,
}

enum ModelStatus {
  notInstalled,
  verifiedReady,
  loadedInMemory,
  checksumFailed,
  incompatible,
}

/// Complete registry record for a local AI model.
class ModelMetadata extends Equatable {
  const ModelMetadata({
    required this.modelId,
    required this.displayName,
    required this.version,
    required this.supportedTasks,
    required this.languages,
    required this.inputSpec,
    required this.outputSpec,
    required this.runtime,
    required this.sizeBytes,
    required this.ramRequirementMb,
    required this.quantization,
    required this.licence,
    required this.hardwareCompatibility,
    required this.expectedSha256,
    required this.status,
    this.localPath,
    this.provenanceUrl,
  });

  final String modelId;
  final String displayName;
  final String version;
  final List<ModelTask> supportedTasks;
  final List<String> languages;
  final String inputSpec;
  final String outputSpec;
  final ModelRuntime runtime;
  final int sizeBytes;
  final int ramRequirementMb;
  final String quantization;
  final String licence;
  final List<String> hardwareCompatibility;
  final String expectedSha256;
  final ModelStatus status;
  final String? localPath;
  final String? provenanceUrl;

  ModelMetadata copyWith({
    ModelStatus? status,
    String? localPath,
  }) {
    return ModelMetadata(
      modelId: modelId,
      displayName: displayName,
      version: version,
      supportedTasks: supportedTasks,
      languages: languages,
      inputSpec: inputSpec,
      outputSpec: outputSpec,
      runtime: runtime,
      sizeBytes: sizeBytes,
      ramRequirementMb: ramRequirementMb,
      quantization: quantization,
      licence: licence,
      hardwareCompatibility: hardwareCompatibility,
      expectedSha256: expectedSha256,
      status: status ?? this.status,
      localPath: localPath ?? this.localPath,
      provenanceUrl: provenanceUrl,
    );
  }

  @override
  List<Object?> get props => [
        modelId,
        displayName,
        version,
        supportedTasks,
        languages,
        inputSpec,
        outputSpec,
        runtime,
        sizeBytes,
        ramRequirementMb,
        quantization,
        licence,
        hardwareCompatibility,
        expectedSha256,
        status,
        localPath,
        provenanceUrl,
      ];
}

/// Measured runtime telemetry for an individual model invocation.
class ModelPerformance extends Equatable {
  const ModelPerformance({
    required this.modelId,
    required this.measuredLatencyMs,
    required this.coldLoadMs,
    required this.inputWidth,
    required this.inputHeight,
    required this.deviceTier,
    required this.recordedAt,
    this.estimatedEnergyMw,
  });

  final String modelId;
  final int measuredLatencyMs;
  final int coldLoadMs;
  final int inputWidth;
  final int inputHeight;
  final String deviceTier;
  final DateTime recordedAt;
  final double? estimatedEnergyMw;

  @override
  List<Object?> get props => [
        modelId,
        measuredLatencyMs,
        coldLoadMs,
        inputWidth,
        inputHeight,
        deviceTier,
        recordedAt,
        estimatedEnergyMw,
      ];
}
