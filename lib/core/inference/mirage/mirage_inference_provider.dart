import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/entities.dart';
import '../../errors/openetra_failure.dart';
import '../ai_model_registry.dart';
import '../model_provider.dart';
import 'mirage_response_parser.dart';

/// Native Cactus Mirage provider bridging via MethodChannel `com.openetra.app/mirage`.
class MirageInferenceProvider implements VisionInferenceProvider {
  MirageInferenceProvider({
    MethodChannel? channel,
    MirageResponseParser? parser,
    this.assetPath = 'assets/models/mirage.cact',
    this.expectedSha256 = AIModelRegistry.mirageSha256,
  })  : _channel = channel ?? const MethodChannel('com.openetra.app/mirage'),
        _parser = parser ?? const MirageResponseParser();

  final MethodChannel _channel;
  final MirageResponseParser _parser;
  final String assetPath;
  final String expectedSha256;

  bool _loaded = false;
  String? _provisionedPath;

  @override
  String get modelId => AIModelRegistry.mirageId;

  @override
  bool get isLoaded => _loaded;

  @override
  Future<ModelPerformance> load({int threads = 0}) async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      final targetPath = p.join(
        supportDir.path,
        'models',
        'mirage',
        AIModelRegistry.mirageRevision,
        'mirage.cact',
      );

      final provResult = await _channel.invokeMapMethod<String, dynamic>(
        'provisionAssetModel',
        {
          'assetPath': assetPath,
          'destPath': targetPath,
          'expectedSha256': expectedSha256,
        },
      );
      _provisionedPath =
          (provResult?['path'] as String?) ?? targetPath;

      final loadResult = await _channel.invokeMapMethod<String, dynamic>(
        'loadModel',
        {
          'path': _provisionedPath,
          'expectedSha256': expectedSha256,
          'threads': threads,
        },
      );
      final mask = (loadResult?['modelsMask'] as num?)?.toInt() ?? 0;
      if ((mask & 4) == 0) {
        throw const ModelIntegrityFailure(
          'Loaded Cactus archive missing CACTUS_VISION bitmask',
        );
      }
      _loaded = true;
      return ModelPerformance(
        modelId: modelId,
        measuredLatencyMs: 0,
        coldLoadMs: (loadResult?['loadMs'] as num?)?.toInt() ?? 0,
        inputWidth: 0,
        inputHeight: 0,
        deviceTier: 'android-native',
        recordedAt: DateTime.now(),
      );
    } on PlatformException catch (e) {
      _loaded = false;
      if (e.code == 'INTEGRITY_ERROR') {
        throw ModelIntegrityFailure(
          e.message ?? 'Mirage SHA-256 verification failed',
          cause: e,
        );
      }
      throw ModelNotLoadedFailure(
        e.message ?? 'Failed loading Mirage native model',
        cause: e,
      );
    } on MissingPluginException catch (e) {
      _loaded = false;
      throw ModelNotLoadedFailure(
        'Native Mirage bridge unavailable on this host',
        cause: e,
      );
    }
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
    if (!_loaded) {
      await load();
    }
    final optionsJson = jsonEncode(profile.toOptionsJson());
    final joinedKeywords =
        (keywords == null || keywords.isEmpty) ? null : keywords.join('\n');

    try {
      final Map<String, dynamic>? raw;
      if (frame.rgbBytes != null) {
        raw = await _channel.invokeMapMethod<String, dynamic>(
          'describeRgb',
          {
            'rgbBytes': frame.rgbBytes,
            'width': frame.width,
            'height': frame.height,
            'optionsJson': optionsJson,
            'language': profile.language,
            'keywords': joinedKeywords,
          },
        );
      } else if (frame.imageFilePath != null) {
        raw = await _channel.invokeMapMethod<String, dynamic>(
          'describeImageFile',
          {
            'path': frame.imageFilePath,
            'optionsJson': optionsJson,
            'language': profile.language,
            'keywords': joinedKeywords,
          },
        );
      } else {
        throw const InferenceFailure(
          'CapturedFrame contains neither rgbBytes nor imageFilePath',
        );
      }

      if (raw == null || raw['json'] == null) {
        throw const InferenceFailure('Mirage native channel returned null');
      }

      final q = (raw['quality'] as Map?)?.cast<String, dynamic>();
      final quality = q == null
          ? frame.qualityMetrics
          : ImageQualityMetrics(
              meanLuma: (q['meanLuma'] as num?)?.toDouble() ??
                  frame.qualityMetrics.meanLuma,
              lumaStdDev: (q['lumaStdDev'] as num?)?.toDouble() ??
                  frame.qualityMetrics.lumaStdDev,
              laplacianVariance: (q['laplacianVariance'] as num?)?.toDouble() ??
                  frame.qualityMetrics.laplacianVariance,
              overexposedRatio: (q['overexposedRatio'] as num?)?.toDouble() ??
                  frame.qualityMetrics.overexposedRatio,
              underexposedRatio: (q['underexposedRatio'] as num?)?.toDouble() ??
                  frame.qualityMetrics.underexposedRatio,
              cameraPitchDegrees: frame.cameraPitchDegrees,
            );

      return _parser.parse(
        rawJson: raw['json'] as String,
        inputWidth: (raw['width'] as num?)?.toInt() ?? frame.width,
        inputHeight: (raw['height'] as num?)?.toInt() ?? frame.height,
        processingDurationMs: (raw['inferenceMs'] as num?)?.toInt() ?? 0,
        imageQuality: quality,
        sourceCapability:
            profile.formSchema != null ? 'mirage_form' : 'mirage_describe',
        timestamp: frame.capturedAt,
      );
    } on PlatformException catch (e) {
      throw InferenceFailure(
        e.message ?? 'Mirage native inference failed',
        cause: e,
      );
    }
  }
}
