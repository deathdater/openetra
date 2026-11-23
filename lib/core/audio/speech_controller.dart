import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import '../inference/model_provider.dart';
import '../resource_management/device_resource_manager.dart';

/// Offline TTS controller enforcing speech-rate/language settings, instant
/// barge-in interruption, offline voice verification, and mic-gating so
/// Openetra's own speech does not self-trigger ASR commands.
class SpeechController implements TtsProvider {
  SpeechController({
    FlutterTts? tts,
    DeviceResourceManager? resourceManager,
    bool enablePlatformTts = true,
  })  : _tts = enablePlatformTts ? (tts ?? FlutterTts()) : null,
        _resourceManager = resourceManager;

  final FlutterTts? _tts;
  final DeviceResourceManager? _resourceManager;

  bool _initialized = false;
  bool _isAssistantSpeaking = false;
  DateTime? _lastSpeechEnd;
  String _currentLocale = 'en-IN';
  double _speechRate = 0.52;
  String _lastSpokenText = '';

  bool get isAssistantSpeaking => _isAssistantSpeaking;
  String get currentLocale => _currentLocale;
  double get speechRate => _speechRate;
  String get lastSpokenText => _lastSpokenText;

  /// Protects ASR microphone capture against TTS acoustic tail echo (350 ms).
  bool get shouldGateMicrophone {
    if (_isAssistantSpeaking) return true;
    final ended = _lastSpeechEnd;
    if (ended == null) return false;
    return DateTime.now().difference(ended).inMilliseconds < 350;
  }

  Future<void> _ensureInitialized() async {
    if (_initialized || _tts == null) return;
    try {
      await _tts.awaitSpeakCompletion(true);
      _tts.setCompletionHandler(() {
        _isAssistantSpeaking = false;
        _lastSpeechEnd = DateTime.now();
      });
      _tts.setCancelHandler(() {
        _isAssistantSpeaking = false;
        _lastSpeechEnd = DateTime.now();
      });
      _tts.setErrorHandler((_) {
        _isAssistantSpeaking = false;
        _lastSpeechEnd = DateTime.now();
      });
      await _tts.setLanguage(_currentLocale);
      await _tts.setSpeechRate(_speechRate);
      _initialized = true;
    } catch (_) {
      _initialized = false;
    }
  }

  @override
  Future<bool> isOfflineVoiceAvailable(String locale) async {
    final rm = _resourceManager;
    if (rm == null) return false;
    final map = await rm.checkOfflineVoiceAvailability([locale]);
    return map[locale] ?? false;
  }

  @override
  Future<List<String>> listOfflineLocales() async {
    final rm = _resourceManager;
    if (rm == null) return const [];
    const candidates = [
      'en-IN',
      'hi-IN',
      'kn-IN',
      'ta-IN',
      'te-IN',
      'ml-IN',
      'mr-IN',
      'bn-IN',
    ];
    final map = await rm.checkOfflineVoiceAvailability(candidates);
    return map.entries.where((e) => e.value).map((e) => e.key).toList();
  }

  Future<void> configure({String? locale, double? rate}) async {
    if (locale != null) _currentLocale = locale;
    if (rate != null) _speechRate = rate.clamp(0.35, 1.0);
    if (_tts != null) {
      await _ensureInitialized();
      try {
        if (locale != null) await _tts.setLanguage(_currentLocale);
        if (rate != null) await _tts.setSpeechRate(_speechRate);
      } catch (_) {}
    }
  }

  @override
  Future<void> speak(
    String text, {
    required String locale,
    required double speechRate,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) return;
    _lastSpokenText = clean;
    _currentLocale = locale;
    _speechRate = speechRate.clamp(0.35, 1.0);

    if (_tts == null) {
      _isAssistantSpeaking = false;
      _lastSpeechEnd = DateTime.now();
      return;
    }
    await _ensureInitialized();
    try {
      await _tts.stop();
      await _tts.setLanguage(_currentLocale);
      await _tts.setSpeechRate(_speechRate);
      _isAssistantSpeaking = true;
      await _tts.speak(clean);
    } finally {
      _isAssistantSpeaking = false;
      _lastSpeechEnd = DateTime.now();
    }
  }

  @override
  Future<void> stop() async {
    _isAssistantSpeaking = false;
    _lastSpeechEnd = DateTime.now();
    if (_tts != null) {
      try {
        await _tts.stop();
      } catch (_) {}
    }
  }
}
