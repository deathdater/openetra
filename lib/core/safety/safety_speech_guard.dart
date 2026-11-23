import '../domain/entities/entities.dart';
import '../localization/openetra_localizer.dart';

/// Deterministic safety speech filter enforcing Section 9.4 non-negotiables
/// on every spoken response before audio output.
class SafetySpeechGuard {
  const SafetySpeechGuard();

  static final List<RegExp> _crossingClaims = [
    RegExp(r'\bsafe to cross\b', caseSensitive: false),
    RegExp(r'\bokay to cross\b', caseSensitive: false),
    RegExp(r'\bcan cross safely\b', caseSensitive: false),
    RegExp(r'\bno cars coming\b', caseSensitive: false),
  ];

  static final List<RegExp> _clearPathClaims = [
    RegExp(r'\bobstacle[- ]free\b', caseSensitive: false),
    RegExp(r'\bpath is clear\b', caseSensitive: false),
    RegExp(r'\bway is clear\b', caseSensitive: false),
    RegExp(r'\bcompletely safe\b', caseSensitive: false),
    RegExp(r'\ball hazards detected\b', caseSensitive: false),
    RegExp(r'\bno hazards exist\b', caseSensitive: false),
    RegExp(r'\benvironment is safe\b', caseSensitive: false),
  ];

  static final RegExp _uncalibratedDistancePattern = RegExp(
    r'\b\d+(?:\.\d+)?\s*(?:meters?|metres?|feet|foot|ft|cm|centimeters?)\s*(?:away|ahead|in front|from you)?\b',
    caseSensitive: false,
  );

  static final List<RegExp> _counterfeitClaims = [
    RegExp(r'\bgenuine note\b', caseSensitive: false),
    RegExp(r'\bauthentic currency\b', caseSensitive: false),
    RegExp(r'\bnot counterfeit\b', caseSensitive: false),
    RegExp(r'\bverified real note\b', caseSensitive: false),
  ];

  static final List<RegExp> _caneReplacementClaims = [
    RegExp(r'\breplaces? your white cane\b', caseSensitive: false),
    RegExp(r'\bno need for a cane\b', caseSensitive: false),
  ];

  ({String text, bool wasSanitized}) sanitize(
    String input, {
    bool hasCalibratedDepth = false,
    String locale = 'en-IN',
  }) {
    String text = input.trim();
    bool sanitized = false;

    for (final rx in _crossingClaims) {
      if (rx.hasMatch(text)) {
        text = text.replaceAll(
          rx,
          OpenetraLocalizer.safetyCrossingReplacement(locale),
        );
        sanitized = true;
      }
    }

    for (final rx in _clearPathClaims) {
      if (rx.hasMatch(text)) {
        text = text.replaceAll(
          rx,
          OpenetraLocalizer.safetyClearPathReplacement(locale),
        );
        sanitized = true;
      }
    }

    if (!hasCalibratedDepth && _uncalibratedDistancePattern.hasMatch(text)) {
      text = text.replaceAll(
        _uncalibratedDistancePattern,
        OpenetraLocalizer.safetyDistanceReplacement(locale),
      );
      sanitized = true;
    }

    for (final rx in _counterfeitClaims) {
      if (rx.hasMatch(text)) {
        text = text.replaceAll(
          rx,
          OpenetraLocalizer.currencyNonCounterfeitDisclaimer(locale),
        );
        sanitized = true;
      }
    }

    for (final rx in _caneReplacementClaims) {
      if (rx.hasMatch(text)) {
        text = text.replaceAll(
          rx,
          'works alongside your white cane and mobility training',
        );
        sanitized = true;
      }
    }

    return (text: text, wasSanitized: sanitized);
  }

  AssistantResponse applyToResponse(
    AssistantResponse response, {
    bool hasCalibratedDepth = false,
  }) {
    final result = sanitize(
      response.spokenText,
      hasCalibratedDepth: hasCalibratedDepth,
      locale: response.locale,
    );
    if (!result.wasSanitized) return response;
    return AssistantResponse(
      responseId: response.responseId,
      spokenText: result.text,
      displaySummary: response.displaySummary,
      locale: response.locale,
      priority: response.priority,
      hapticPattern: response.hapticPattern,
      timestamp: response.timestamp,
      wasSafetySanitized: true,
      isDegraded: response.isDegraded,
      sourceObservationId: response.sourceObservationId,
    );
  }
}
