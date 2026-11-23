import 'package:flutter/services.dart';
import 'local_model_catalogue.dart';

class ModelVerificationResult {
  const ModelVerificationResult({
    required this.verified,
    this.sha256,
    this.sizeBytes = 0,
    this.error,
  });

  final bool verified;
  final String? sha256;
  final int sizeBytes;
  final String? error;
}

class ModelDownloadResult {
  const ModelDownloadResult({
    required this.success,
    this.filePath,
    this.sizeBytes = 0,
    this.cancelled = false,
    this.error,
  });

  final bool success;
  final String? filePath;
  final int sizeBytes;
  final bool cancelled;
  final String? error;
}

class ModelDownloadProgress {
  const ModelDownloadProgress({
    required this.modelId,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.progress,
    required this.status,
  });

  final String modelId;
  final int downloadedBytes;
  final int totalBytes;
  final double progress;
  final String status;
}

/// Replaceable on-device LLM inference and model-file bridge contract.
abstract class LocalLlmEngine {
  Future<DeviceHardwareProfile> probeDevice();

  Stream<ModelDownloadProgress> get downloadProgressStream;

  Future<ModelDownloadResult> downloadModel({
    required LocalModelSpec spec,
    required bool wifiOnly,
    String? authToken,
  });

  Future<void> cancelDownload();

  Future<ModelVerificationResult> verifyLocalModelFile({
    required String modelId,
    required String filePath,
    String? expectedSha256,
  });

  Future<bool> initializeModel({
    required String modelId,
    required String filePath,
  });

  Future<bool> runSmokeTest();

  Future<String?> generateBoundedSummary({
    required String systemInstruction,
    required String boundedHistoryContext,
    required String userQuestion,
    int maxOutputTokens = 160,
  });

  Future<void> unloadModel();

  Future<bool> deleteModelFiles(String modelId);

  String? get loadedModelId;
}

/// Native Android Kotlin bridge (`com.openetra.app/local_intelligence`) for
/// hardware probing, resumable HTTPS download, SHA-256 package verification,
/// file lifecycle, and LiteRT-LM inference. Fails safely on unsupported hosts.
class NativeLocalLlmEngine implements LocalLlmEngine {
  NativeLocalLlmEngine([
    MethodChannel? channel,
    EventChannel? progressChannel,
  ])  : _channel =
            channel ?? const MethodChannel('com.openetra.app/local_intelligence'),
        _progressChannel = progressChannel ??
            const EventChannel(
              'com.openetra.app/local_intelligence_download_progress',
            );

  final MethodChannel _channel;
  final EventChannel _progressChannel;
  String? _loadedModelId;
  Stream<ModelDownloadProgress>? _cachedProgressStream;

  @override
  String? get loadedModelId => _loadedModelId;

  @override
  Stream<ModelDownloadProgress> get downloadProgressStream {
    _cachedProgressStream ??= _progressChannel
        .receiveBroadcastStream()
        .where((event) => event is Map)
        .map((raw) {
          final map = Map<String, dynamic>.from(raw as Map);
          return ModelDownloadProgress(
            modelId: map['modelId']?.toString() ?? '',
            downloadedBytes: (map['downloadedBytes'] as num?)?.toInt() ?? 0,
            totalBytes: (map['totalBytes'] as num?)?.toInt() ?? 0,
            progress: (map['progress'] as num?)?.toDouble() ?? 0.0,
            status: map['status']?.toString() ?? 'downloading',
          );
        })
        .handleError((_) {});
    return _cachedProgressStream!;
  }

  @override
  Future<DeviceHardwareProfile> probeDevice() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('probeDevice');
      if (res == null) return DeviceHardwareProfile.unknown;
      final abis = (res['supportedAbis'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[];
      return DeviceHardwareProfile(
        androidApiLevel: (res['androidApiLevel'] as num?)?.toInt() ?? 0,
        totalRamMb: (res['totalRamMb'] as num?)?.toInt() ?? 0,
        availableStorageMb: (res['availableStorageMb'] as num?)?.toInt() ?? 0,
        supportedAbis: abis,
        liteRtLmRuntimeAvailable: res['liteRtLmRuntimeAvailable'] == true,
      );
    } on MissingPluginException {
      return DeviceHardwareProfile.unknown;
    } catch (_) {
      return DeviceHardwareProfile.unknown;
    }
  }

  @override
  Future<ModelDownloadResult> downloadModel({
    required LocalModelSpec spec,
    required bool wifiOnly,
    String? authToken,
  }) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'downloadModel',
        {
          'modelId': spec.modelId,
          'downloadUrl': spec.downloadUrl,
          'fileName': spec.fileName,
          'expectedSizeMb': spec.packageSizeMb,
          'wifiOnly': wifiOnly,
          'authToken': authToken,
        },
      );
      if (res == null) {
        return const ModelDownloadResult(
          success: false,
          error: 'Native model downloader returned an empty response.',
        );
      }
      return ModelDownloadResult(
        success: res['success'] == true,
        filePath: res['filePath'] as String?,
        sizeBytes: (res['sizeBytes'] as num?)?.toInt() ?? 0,
        cancelled: res['cancelled'] == true,
        error: res['error'] as String?,
      );
    } on MissingPluginException {
      return const ModelDownloadResult(
        success: false,
        error: 'Model downloading is only available on Android devices.',
      );
    } catch (e) {
      return ModelDownloadResult(success: false, error: e.toString());
    }
  }

  @override
  Future<void> cancelDownload() async {
    try {
      await _channel.invokeMethod<void>('cancelDownload');
    } catch (_) {}
  }

  @override
  Future<ModelVerificationResult> verifyLocalModelFile({
    required String modelId,
    required String filePath,
    String? expectedSha256,
  }) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'verifyLocalModelFile',
        {
          'modelId': modelId,
          'filePath': filePath,
          'expectedSha256': expectedSha256,
        },
      );
      if (res == null) {
        return const ModelVerificationResult(
          verified: false,
          error: 'Native model verification returned empty result.',
        );
      }
      return ModelVerificationResult(
        verified: res['verified'] == true,
        sha256: res['sha256'] as String?,
        sizeBytes: (res['sizeBytes'] as num?)?.toInt() ?? 0,
        error: res['error'] as String?,
      );
    } on MissingPluginException {
      return const ModelVerificationResult(
        verified: false,
        error: 'On-device model verification is unavailable on this host.',
      );
    } catch (e) {
      return ModelVerificationResult(verified: false, error: e.toString());
    }
  }

  @override
  Future<bool> initializeModel({
    required String modelId,
    required String filePath,
  }) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'initializeModel',
        {'modelId': modelId, 'filePath': filePath},
      );
      final ok = res?['initialized'] == true;
      _loadedModelId = ok ? modelId : null;
      return ok;
    } catch (_) {
      _loadedModelId = null;
      return false;
    }
  }

  @override
  Future<bool> runSmokeTest() async {
    if (_loadedModelId == null) return false;
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('smokeTest');
      return res?['passed'] == true;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<String?> generateBoundedSummary({
    required String systemInstruction,
    required String boundedHistoryContext,
    required String userQuestion,
    int maxOutputTokens = 160,
  }) async {
    if (_loadedModelId == null) return null;
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'generateSummary',
        {
          'systemInstruction': systemInstruction,
          'historyContext': boundedHistoryContext,
          'userQuestion': userQuestion,
          'maxOutputTokens': maxOutputTokens,
        },
      );
      final text = res?['text']?.toString().trim();
      return (text != null && text.isNotEmpty) ? text : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> unloadModel() async {
    _loadedModelId = null;
    try {
      await _channel.invokeMethod<void>('unloadModel');
    } catch (_) {}
  }

  @override
  Future<bool> deleteModelFiles(String modelId) async {
    if (_loadedModelId == modelId) {
      await unloadModel();
    }
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'deleteModelFiles',
        {'modelId': modelId},
      );
      return res?['deleted'] == true;
    } catch (_) {
      return false;
    }
  }
}
