import '../domain/entities/entities.dart';

/// Deterministic offline command router supporting English, Hindi (Devanagari
/// + Hinglish), and Kannada phrases without cloud NLP dependencies.
class VoiceIntentRouter {
  const VoiceIntentRouter();

  VoiceIntent parse(String transcript) {
    final normalized = transcript.trim().toLowerCase();
    if (normalized.isEmpty) {
      return VoiceIntent(
        type: VoiceIntentType.unknown,
        rawTranscript: transcript,
        confidence: 0.0,
      );
    }

    if (_matchesAny(normalized, const [
      'stop',
      'quiet',
      'silence',
      'mute',
      'रुको',
      'बंद',
      'chup',
      'nillisu',
      'ನಿಲ್ಲಿಸು',
    ])) {
      return VoiceIntent(
        type: VoiceIntentType.stopSpeaking,
        rawTranscript: transcript,
      );
    }

    if (_matchesAny(normalized, const [
      'repeat',
      'say again',
      'फिर से',
      'dobara',
      'matte helu',
      'ಮತ್ತೆ ಹೇಳು',
    ])) {
      return VoiceIntent(
        type: VoiceIntentType.repeatLast,
        rawTranscript: transcript,
      );
    }

    if (_matchesAny(normalized, const [
      'hazard',
      'danger',
      'obstacle',
      'safe to walk',
      'watch out',
      'खतरा',
      'khatra',
      'savdhan',
      'apaya',
      'ಅಪಾಯ',
      'ಎಚ್ಚರಿಕೆ',
    ])) {
      return VoiceIntent(
        type: VoiceIntentType.lookForHazards,
        rawTranscript: transcript,
      );
    }

    if (_matchesAny(normalized, const [
      'currency',
      'note',
      'rupee',
      'money',
      'cash',
      'नोट',
      'रुपये',
      'paisa',
      'notu',
      'ನೋಟು',
      'ಹಣ',
    ])) {
      return VoiceIntent(
        type: VoiceIntentType.identifyCurrency,
        rawTranscript: transcript,
      );
    }

    if (_matchesAny(normalized, const [
      'read',
      'text',
      'document',
      'label',
      'sign',
      'पढ़ो',
      'padho',
      'odu',
      'ಓದು',
    ])) {
      return VoiceIntent(
        type: VoiceIntentType.readText,
        rawTranscript: transcript,
      );
    }

    final findObjectTarget = _extractFindTarget(normalized);
    if (findObjectTarget != null) {
      return VoiceIntent(
        type: VoiceIntentType.findObject,
        rawTranscript: transcript,
        targetArgument: findObjectTarget,
      );
    }

    if (_matchesAny(normalized, const [
      'eco mode',
      'balanced mode',
      'battery saver',
      'hazard mode',
      'reading mode',
    ])) {
      return VoiceIntent(
        type: VoiceIntentType.switchMode,
        rawTranscript: transcript,
        targetArgument: normalized,
      );
    }

    if (_matchesAny(normalized, const [
      'hindi',
      'kannada',
      'english',
      'tamil',
      'telugu',
      'language',
      'भाषा',
      'bhasha',
      'ಭಾಷೆ',
    ])) {
      return VoiceIntent(
        type: VoiceIntentType.switchLanguage,
        rawTranscript: transcript,
        targetArgument: normalized,
      );
    }

    if (_matchesAny(normalized, const [
      'settings',
      'preferences',
      'सेटिंग',
      'ಸೆಟ್ಟಿಂಗ್',
    ])) {
      return VoiceIntent(
        type: VoiceIntentType.openSettings,
        rawTranscript: transcript,
      );
    }

    if (_matchesAny(normalized, const [
      'what is on the left',
      'what is on my left',
      'on the left',
      'on the right',
      'in front',
      'any chairs',
      'what changed',
      'any text',
      'what text',
      'left side',
      'right side',
      'बायें',
      'दायें',
      'ಎಡ',
      'ಬಲ',
    ])) {
      return VoiceIntent(
        type: VoiceIntentType.followUpQuery,
        rawTranscript: transcript,
        targetArgument: normalized,
      );
    }

    if (_matchesAny(normalized, const [
      'describe',
      'surroundings',
      'around me',
      'what do you see',
      'front of me',
      'क्या है',
      'आसपास',
      'kya hai',
      'suttamutta',
      'ಸುತ್ತಮುತ್ತ',
      'ವಿವರಿಸು',
    ])) {
      return VoiceIntent(
        type: VoiceIntentType.describeSurroundings,
        rawTranscript: transcript,
      );
    }

    // Fallback to follow-up query if phrase contains question words.
    if (normalized.startsWith('is there') ||
        normalized.startsWith('are there') ||
        normalized.startsWith('where is') ||
        normalized.startsWith('what ')) {
      return VoiceIntent(
        type: VoiceIntentType.followUpQuery,
        rawTranscript: transcript,
        targetArgument: normalized,
      );
    }

    return VoiceIntent(
      type: VoiceIntentType.unknown,
      rawTranscript: transcript,
      confidence: 0.25,
    );
  }

  static bool _matchesAny(String input, List<String> phrases) {
    for (final p in phrases) {
      if (input.contains(p)) return true;
    }
    return false;
  }

  static String? _extractFindTarget(String input) {
    final patterns = [
      RegExp(r'(?:find|locate|where is|search for)\s+(?:my\s+)?(.+)'),
      RegExp(r'(?:dhoondo|khojo)\s+(.+)'),
      RegExp(r'(?:huduku)\s+(.+)'),
    ];
    for (final regex in patterns) {
      final match = regex.firstMatch(input);
      if (match != null) {
        final item = match.group(1)?.trim();
        if (item != null && item.isNotEmpty) {
          return item.replaceAll(RegExp(r'[?.!]+$'), '').trim();
        }
      }
    }
    return null;
  }
}
