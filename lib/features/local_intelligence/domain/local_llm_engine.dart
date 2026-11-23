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

/// Replaceable on-device LLM inference and model-file bridge contract.
abstract class LocalLlmEngine {
  Future<DeviceHardwareProfile> probeDevice();

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
/// hardware probing, SHA-256 package verification, file lifecycle, and
/// LiteRT-LM inference. Fails safely to null/false on unsupported hosts.
class NativeLocalLlmEngine implements LocalLlmEngine {
  NativeLocalLlmEngine([MethodChannel? channel])
      : _channel =
            channel ?? const MethodChannel('com.openetra.app/local_intelligence');

  final MethodChannel _channel;
  String? _loadedModelId;

  @override
  String? get loadedModelId => _loadedModelId;

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
