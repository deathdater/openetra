import 'package:flutter/services.dart';
import '../domain/entities/entities.dart';
import '../errors/openetra_failure.dart';
import '../inference/model_provider.dart';

/// Replaceable camera capture abstraction allowing native CameraX or deterministic fixtures.
abstract class CameraSource {
  Future<void> start({int minIntervalMs = 500});
  Future<void> stop();
  Future<CapturedFrame> captureFrame();
}

/// Bridges to Android CameraXCaptureManager via MethodChannel `com.openetra.app/camera`.
class CameraControllerBridge implements CameraSource {
  CameraControllerBridge([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel('com.openetra.app/camera');

  final MethodChannel _channel;
  bool _started = false;

  bool get isStarted => _started;

  @override
  Future<void> start({int minIntervalMs = 500}) async {
    try {
      await _channel.invokeMethod<void>('startCamera', {
        'minIntervalMs': minIntervalMs,
      });
      _started = true;
    } on PlatformException catch (e) {
      throw PermissionFailure(
        e.message ?? 'Camera startup failed',
        cause: e,
      );
    } on MissingPluginException {
      _started = true;
    }
  }

  @override
  Future<void> stop() async {
    _started = false;
    try {
      await _channel.invokeMethod<void>('stopCamera');
    } on MissingPluginException {
      // No-op on headless test host.
    }
  }

  @override
  Future<CapturedFrame> captureFrame() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('captureFrame');
      if (result == null) {
        throw const InferenceFailure('Camera returned empty frame payload');
      }
      final rgbBytes = result['rgbBytes'] as Uint8List?;
      final width = (result['width'] as num?)?.toInt() ?? 0;
      final height = (result['height'] as num?)?.toInt() ?? 0;
      final pitch = (result['pitchDegrees'] as num?)?.toDouble();
      final q = (result['quality'] as Map?)?.cast<String, dynamic>();

      final quality = q == null
          ? ImageQualityMetrics.nominal
          : ImageQualityMetrics(
              meanLuma: (q['meanLuma'] as num?)?.toDouble() ?? 128.0,
              lumaStdDev: (q['lumaStdDev'] as num?)?.toDouble() ?? 40.0,
              laplacianVariance:
                  (q['laplacianVariance'] as num?)?.toDouble() ?? 120.0,
              overexposedRatio:
                  (q['overexposedRatio'] as num?)?.toDouble() ?? 0.0,
              underexposedRatio:
                  (q['underexposedRatio'] as num?)?.toDouble() ?? 0.0,
              cameraPitchDegrees: pitch,
            );

      return CapturedFrame(
        width: width,
        height: height,
        capturedAt: DateTime.now(),
        qualityMetrics: quality,
        rgbBytes: rgbBytes,
        cameraPitchDegrees: pitch,
      );
    } on PlatformException catch (e) {
      throw InferenceFailure(e.message ?? 'Failed to capture camera frame', cause: e);
    }
  }
}
