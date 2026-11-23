import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import '../audio/haptic_feedback_service.dart';
import '../audio/speech_controller.dart';
import '../domain/entities/entities.dart';

/// Coordinates TalkBack announcements, priority offline TTS, and haptics.
class AccessibilityAnnouncer {
  AccessibilityAnnouncer({
    required this.speechController,
    required this.hapticService,
  });

  final SpeechController speechController;
  final HapticFeedbackService hapticService;

  AssistantResponse? _lastResponse;
  AssistantResponse? get lastResponse => _lastResponse;

  Future<void> announce(
    AssistantResponse response, {
    bool sendSemanticAnnouncement = true,
  }) async {
    _lastResponse = response;
    await hapticService.trigger(response.hapticPattern);
    if (sendSemanticAnnouncement &&
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures.accessibleNavigation) {
      SemanticsService.announce(response.spokenText, TextDirection.ltr);
    }
    await speechController.speak(
      response.spokenText,
      locale: response.locale,
      speechRate: speechController.speechRate,
    );
  }

  Future<void> repeatLast() async {
    final last = _lastResponse;
    if (last == null) {
      await speechController.speak(
        'Nothing has been announced yet.',
        locale: speechController.currentLocale,
        speechRate: speechController.speechRate,
      );
      return;
    }
    await speechController.speak(
      last.spokenText,
      locale: last.locale,
      speechRate: speechController.speechRate,
    );
  }

  Future<void> interrupt() async {
    await speechController.stop();
  }
}
