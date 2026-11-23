import 'package:uuid/uuid.dart';
import '../audio/bloc/audio_bloc.dart';
import '../audio/speech_controller.dart';
import '../domain/entities/entities.dart';

/// Arbitrates all spoken/haptic outputs through the single existing [AudioBloc]
/// and [SpeechController], enforcing priority preemption for emergency cues,
/// echo-safe microphone gating, and cooldown deduplication for background state updates.
class AudioArbitrator {
  AudioArbitrator({
    required this.audioBloc,
    required this.speechController,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AudioBloc audioBloc;
  final SpeechController speechController;
  final DateTime Function() _clock;
  static const _uuid = Uuid();

  final Map<String, DateTime> _categoryCooldown = {};

  bool get isSpeaking =>
      audioBloc.state.isSpeaking || speechController.isAssistantSpeaking;

  bool get canCaptureMicrophone => !speechController.shouldGateMicrophone;

  /// Preempts lower-priority narration immediately when an emergency or critical
  /// alert arrives.
  Future<void> speakPriorityEmergency(
    String message, {
    String locale = 'en-IN',
  }) async {
    audioBloc.add(const InterruptSpeechRequested());
    audioBloc.add(
      SpeakAssistantResponse(
        AssistantResponse(
          responseId: _uuid.v4(),
          spokenText: message,
          displaySummary: message,
          locale: locale,
          priority: SpeechPriority.critical,
          hapticPattern: HapticPattern.critical,
          timestamp: _clock(),
        ),
      ),
    );
  }

  /// Delivers concise transition cues (e.g. flashlight on/off, gesture mode)
  /// with deduplication cooldown so repeated sensor samples never spam TTS.
  void announceTransition({
    required String categoryKey,
    required String spokenText,
    required String locale,
    Duration cooldown = const Duration(seconds: 2),
    SpeechPriority priority = SpeechPriority.normal,
    HapticPattern haptic = HapticPattern.confirm,
  }) {
    final now = _clock();
    final last = _categoryCooldown[categoryKey];
    if (last != null && now.difference(last) < cooldown) {
      return;
    }
    _categoryCooldown[categoryKey] = now;
    audioBloc.add(
      SpeakAssistantResponse(
        AssistantResponse(
          responseId: _uuid.v4(),
          spokenText: spokenText,
          displaySummary: spokenText,
          locale: locale,
          priority: priority,
          hapticPattern: haptic,
          timestamp: now,
        ),
      ),
    );
  }

  void interruptAllSpeech() {
    audioBloc.add(const InterruptSpeechRequested());
  }

  /// Cancels any obsolete dial selection announcement immediately before
  /// speaking the newly focused option so rapid browsing never queues a backlog.
  void announceSelection({
    required String spokenText,
    String locale = 'en-IN',
  }) {
    audioBloc.add(const InterruptSpeechRequested());
    audioBloc.add(
      SpeakAssistantResponse(
        AssistantResponse(
          responseId: _uuid.v4(),
          spokenText: spokenText,
          displaySummary: spokenText,
          locale: locale,
          priority: SpeechPriority.normal,
          hapticPattern: HapticPattern.none,
          timestamp: _clock(),
        ),
      ),
    );
  }
}
