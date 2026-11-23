import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../domain/entities/entities.dart';
import '../errors/openetra_failure.dart';
import '../inference/model_provider.dart';
import 'voice_intent_router.dart';

/// Native Android offline ASR + Silero VAD provider over MethodChannel
/// `com.openetra.app/speech` (`sherpa-onnx` 2.0.3 + Android on-device fallback).
class NativeOfflineAsrProvider implements AsrProvider {
  NativeOfflineAsrProvider({
    MethodChannel? channel,
    VoiceIntentRouter? intentRouter,
  })  : _channel = channel ?? const MethodChannel('com.openetra.app/speech'),
        _intentRouter = intentRouter ?? const VoiceIntentRouter();

  final MethodChannel _channel;
  final VoiceIntentRouter _intentRouter;
  static const _uuid = Uuid();

  @override
  String get providerId => 'sherpa-onnx-indicconformer';

  @override
  List<String> get supportedLocales => const [
        'en-IN',
        'hi-IN',
        'kn-IN',
        'ta-IN',
        'te-IN',
        'ml-IN',
        'mr-IN',
        'bn-IN',
      ];

  Future<bool> initVad() async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>('initVad');
      return (res?['vadInitialized'] as bool?) ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  Future<Map<String, dynamic>> detectSpeechSegments(List<double> samples) async {
    final res = await _channel.invokeMapMethod<String, dynamic>(
      'detectSpeechSegments',
      {'samples': samples},
    );
    return res ?? const {'speechDetected': false, 'segmentCount': 0};
  }

  @override
  Future<bool> isLocalePackAvailable(String locale) async {
    try {
      final status = await _channel.invokeMapMethod<String, dynamic>(
        'status',
        {'locale': locale},
      );
      if (status == null) return false;
      return (status['asrPackLoaded'] as bool? ?? false) ||
          (status['osOnDeviceSpeechAvailable'] as bool? ?? false);
    } on MissingPluginException {
      return false;
    }
  }

  Future<void> loadPack({
    required String locale,
    required String modelPath,
    required String tokensPath,
    required String expectedSha256,
  }) async {
    try {
      await _channel.invokeMethod<void>('loadAsrPack', {
        'locale': locale,
        'modelPath': modelPath,
        'tokensPath': tokensPath,
        'expectedSha256': expectedSha256,
      });
    } on PlatformException catch (e) {
      if (e.code == 'INTEGRITY_ERROR') {
        throw ModelIntegrityFailure(e.message ?? 'ASR checksum error', cause: e);
      }
      throw ModelNotLoadedFailure(e.message ?? 'Failed loading ASR pack', cause: e);
    }
  }

  @override
  Future<SpeechRecognitionResult> transcribePcm16k(
    List<double> samples, {
    required String locale,
  }) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'transcribePcm16k',
        {'samples': samples, 'locale': locale},
      );
      return _buildResult(res, locale: locale);
    } on PlatformException catch (e) {
      throw InferenceFailure(e.message ?? 'Offline transcription failed', cause: e);
    }
  }

  Future<SpeechRecognitionResult> recordAndRecognizeOffline({
    required String locale,
    int maxDurationMs = 4000,
  }) async {
    try {
      final res = await _channel.invokeMapMethod<String, dynamic>(
        'recordAndRecognizeOffline',
        {'locale': locale, 'maxDurationMs': maxDurationMs},
      );
      return _buildResult(res, locale: locale);
    } on PlatformException catch (e) {
      if (e.code == 'MIC_PERMISSION') {
        throw PermissionFailure(e.message ?? 'Microphone permission denied', cause: e);
      }
      throw OfflineVoiceUnavailableFailure(
        e.message ?? 'No offline ASR pack available for $locale',
        cause: e,
      );
    } on MissingPluginException catch (e) {
      throw OfflineVoiceUnavailableFailure(
        'Offline speech bridge unavailable on test host',
        cause: e,
      );
    }
  }

  SpeechRecognitionResult _buildResult(
    Map<String, dynamic>? raw, {
    required String locale,
  }) {
    final text = (raw?['transcript'] as String? ?? '').trim();
    final engine = (raw?['engine'] as String?) ?? providerId;
    final infMs = (raw?['inferenceMs'] as num?)?.toInt() ?? 0;
    final intent = _intentRouter.parse(text);
    return SpeechRecognitionResult(
      provenance: ObservationProvenance(
        observationId: _uuid.v4(),
        timestamp: DateTime.now(),
        modelId: engine,
        modelVersion: '2.0.3',
        confidence: intent.confidence,
        inputWidth: 0,
        inputHeight: 0,
        processingDurationMs: infMs,
        sourceCapability: 'offline_asr',
        validationStatus:
            text.isEmpty ? ValidationStatus.uncertain : ValidationStatus.verified,
      ),
      transcript: text,
      locale: locale,
      intent: intent,
      isOfflineEngine: true,
    );
  }
}
