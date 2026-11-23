import 'package:equatable/equatable.dart';

/// Base sealed failure type across Openetra domain and infrastructure layers.
abstract class OpenetraFailure extends Equatable implements Exception {
  const OpenetraFailure(this.message, {this.code, this.cause});

  final String message;
  final String? code;
  final Object? cause;

  @override
  List<Object?> get props => [message, code, cause];

  @override
  String toString() => '$runtimeType(code: $code, message: $message)';
}

class ModelNotLoadedFailure extends OpenetraFailure {
  const ModelNotLoadedFailure(super.message, {super.code = 'MODEL_NOT_LOADED', super.cause});
}

class ModelIntegrityFailure extends OpenetraFailure {
  const ModelIntegrityFailure(super.message, {super.code = 'MODEL_INTEGRITY_ERROR', super.cause});
}

class InferenceFailure extends OpenetraFailure {
  const InferenceFailure(super.message, {super.code = 'INFERENCE_ERROR', super.cause});
}

class ImageQualityFailure extends OpenetraFailure {
  const ImageQualityFailure(super.message, {super.code = 'IMAGE_QUALITY_DEGRADED', super.cause});
}

class OfflineVoiceUnavailableFailure extends OpenetraFailure {
  const OfflineVoiceUnavailableFailure(
    super.message, {
    super.code = 'OFFLINE_VOICE_UNAVAILABLE',
    super.cause,
  });
}

class PermissionFailure extends OpenetraFailure {
  const PermissionFailure(super.message, {super.code = 'PERMISSION_DENIED', super.cause});
}

class ThermalThrottleFailure extends OpenetraFailure {
  const ThermalThrottleFailure(super.message, {super.code = 'THERMAL_THROTTLE', super.cause});
}

class StorageFailure extends OpenetraFailure {
  const StorageFailure(super.message, {super.code = 'STORAGE_ERROR', super.cause});
}
