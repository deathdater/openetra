import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import '../inference/model_provider.dart';
import '../resource_management/device_resource_manager.dart';

/// Offline TTS controller enforcing speech-rate/language settings, strict
/// sequential completion (never overriding an in-flight spoken statement unless
/// explicitly interrupted), offline voice verification, and mic-gating so
/// Openetra's own speech does not self-trigger ASR commands.
class SpeechController implements TtsProvider {
  SpeechController({
    FlutterTts? tts,
    DeviceResourceManager? resourceManager,
    bool enablePlatformTts = true,
    this.testSpeakHook,
  })  : _tts = enablePlatformTts ? (tts ?? FlutterTts()) : null,
        _resourceManager = resourceManager;

  final FlutterTts? _tts;
  final DeviceResourceManager? _resourceManager;

  /// Optional deterministic async hook used in host tests to verify strict
  /// sequential speech ordering without platform TTS hardware.
  final Future<void> Function(String text)? testSpeakHook;

  bool _initialized = false;
  bool _isAssistantSpeaking = false;
  DateTime? _lastSpeechEnd;
  String _currentLocale = 'en-IN';
  double _speechRate = 0.52;
  String _lastSpokenText = '';

  int _generation = 0;
  int _pendingCount = 0;
  Future<void> _speechChain = Future<void>.value();
  Completer<void>? _activeUtteranceCompleter;

  bool get isAssistantSpeaking => _isAssistantSpeaking;
  bool get hasPendingSpeech => _pendingCount > 0;
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

  /// Resolves only after the currently spoken statement and all queued
  /// statements ahead of this call have finished speaking completely.
  Future<void> waitUntilSpeechIdle() async {
    try {
      await _speechChain;
    } catch (_) {}
  }

  void _completeActiveUtterance() {
    _isAssistantSpeaking = false;
    _lastSpeechEnd = DateTime.now();
    final c = _activeUtteranceCompleter;
    _activeUtteranceCompleter = null;
    if (c != null && !c.isCompleted) {
      c.complete();
    }
  }

  Future<void> _ensureInitialized() async {
    if (_initialized || _tts == null) return;
    try {
      await _tts.awaitSpeakCompletion(true);
      _tts.setCompletionHandler(_completeActiveUtterance);
      _tts.setCancelHandler(_completeActiveUtterance);
      _tts.setErrorHandler((_) => _completeActiveUtterance());
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
    bool interruptCurrent = false,
  }) async {
    final clean = text.trim();
    if (clean.isEmpty) return;

    if (interruptCurrent) {
      await stop();
    }

    final myGeneration = _generation;
    _pendingCount++;

    final previous = _speechChain;
    final done = Completer<void>();
    _speechChain = done.future;

    try {
      await previous;
      if (myGeneration != _generation) return;

      _lastSpokenText = clean;
      _currentLocale = locale;
      _speechRate = speechRate.clamp(0.35, 1.0);

      if (testSpeakHook != null) {
        _isAssistantSpeaking = true;
        try {
          await testSpeakHook!(clean);
        } finally {
          _isAssistantSpeaking = false;
          _lastSpeechEnd = DateTime.now();
        }
        return;
      }

      if (_tts == null) {
        _isAssistantSpeaking = false;
        _lastSpeechEnd = DateTime.now();
        return;
      }

      await _ensureInitialized();
      if (myGeneration != _generation) return;

      final utteranceCompleter = Completer<void>();
      _activeUtteranceCompleter = utteranceCompleter;
      try {
        await _tts.setLanguage(_currentLocale);
        await _tts.setSpeechRate(_speechRate);
        _isAssistantSpeaking = true;
        final result = await _tts.speak(clean);
        // If flutter_tts returned immediately (platform does not block in speak),
        // wait for the completion/cancel/error handler before releasing the queue.
        if (!utteranceCompleter.isCompleted && result == 1) {
          await utteranceCompleter.future.timeout(
            Duration(milliseconds: (clean.length * 140).clamp(4000, 45000)),
            onTimeout: () {},
          );
        }
      } finally {
        _completeActiveUtterance();
      }
    } finally {
      _pendingCount = _pendingCount > 0 ? _pendingCount - 1 : 0;
      if (!done.isCompleted) done.complete();
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
    _completeActiveUtterance();
    if (_tts != null) {
      try {
        await _tts.stop();
      } catch (_) {}
    }
  }
}
