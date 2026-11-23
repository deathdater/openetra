import 'package:flutter_test/flutter_test.dart';
import 'package:openetra/core/domain/entities/entities.dart';
import 'package:openetra/core/localization/openetra_localizer.dart';
import 'package:openetra/core/safety/safety_speech_guard.dart';

void main() {
  group('OpenetraLocalizer trilingual native authoring (en-IN, hi-IN, kn-IN)', () {
    test('formats relativePosition in English, Hindi, and Kannada', () {
      const pos = RelativePosition(
        horizontal: HorizontalZone.left,
        vertical: VerticalZone.groundLevel,
      );
      expect(OpenetraLocalizer.relativePosition(pos, 'en-IN'), 'left (foreground)');
      expect(OpenetraLocalizer.relativePosition(pos, 'hi-IN'), 'बाईं ओर (पास नीचे)');
      expect(OpenetraLocalizer.relativePosition(pos, 'kn-IN'), 'ಎಡಭಾಗದಲ್ಲಿ (ಹತ್ತಿರ ಕೆಳಭಾಗದಲ್ಲಿ)');
    });

    test('authors severity, degraded notice, no-hazard advisory, currency, and scene phrases directly', () {
      expect(
        OpenetraLocalizer.severityPrefix(HazardSeverity.critical, 'hi-IN'),
        'तत्काल चेतावनी:',
      );
      expect(
        OpenetraLocalizer.severityPrefix(HazardSeverity.critical, 'kn-IN'),
        'ತುರ್ತು ಎಚ್ಚರಿಕೆ:',
      );

      expect(
        OpenetraLocalizer.degradedNotice(const ['low light'], 'hi-IN'),
        contains('low light'),
      );
      expect(
        OpenetraLocalizer.degradedNotice(const ['blur'], 'kn-IN'),
        contains('ಸ್ಕ್ಯಾನಿಂಗ್ ಸೀಮಿತವಾಗಿದೆ'),
      );

      expect(
        OpenetraLocalizer.noHazardsAdvisory('en-IN'),
        contains('white cane'),
      );
      expect(
        OpenetraLocalizer.noHazardsAdvisory('hi-IN'),
        contains('सफेद छड़ी'),
      );
      expect(
        OpenetraLocalizer.noHazardsAdvisory('kn-IN'),
        contains('ಬಿಳಿ ಕೋಲು'),
      );

      expect(
        OpenetraLocalizer.currencyIdentified(InrDenomination.inr500, 88, 500, 'hi-IN'),
        allOf(contains('500 रुपये'), contains('असली है या नकली')),
      );
      expect(
        OpenetraLocalizer.currencyIdentified(InrDenomination.inr200, 91, 200, 'kn-IN'),
        allOf(contains('200 ರೂಪಾಯಿ'), contains('ನಕಲಿಯೇ')),
      );

      expect(
        OpenetraLocalizer.sceneIntro(
          environment: 'kitchen',
          surface: 'tile',
          lighting: 'bright',
          locale: 'hi-IN',
        ),
        contains('kitchen'),
      );
      expect(
        OpenetraLocalizer.sceneIntro(
          environment: 'living room',
          locale: 'kn-IN',
        ),
        contains('living room'),
      );
    });
  });

  group('SafetySpeechGuard enforcement across EN/HI/KN', () {
    const guard = SafetySpeechGuard();

    test('blocks unsafe crossing and clear-path claims in all 3 locales', () {
      for (final locale in const ['en-IN', 'hi-IN', 'kn-IN']) {
        final crossing = guard.sanitize('You are safe to cross now.', locale: locale);
        expect(crossing.wasSanitized, isTrue);
        expect(crossing.text.toLowerCase(), isNot(contains('safe to cross')));
        expect(crossing.text, contains(OpenetraLocalizer.safetyCrossingReplacement(locale)));

        final clearPath = guard.sanitize('The path is clear ahead.', locale: locale);
        expect(clearPath.wasSanitized, isTrue);
        expect(clearPath.text.toLowerCase(), isNot(contains('path is clear')));
        expect(clearPath.text, contains(OpenetraLocalizer.safetyClearPathReplacement(locale)));
      }
    });

    test('strips uncalibrated distances when hasCalibratedDepth is false and keeps when true', () {
      const sample = 'Chair is 1.5 meters away in front.';
      final uncalibratedHi = guard.sanitize(sample, hasCalibratedDepth: false, locale: 'hi-IN');
      expect(uncalibratedHi.wasSanitized, isTrue);
      expect(uncalibratedHi.text, isNot(contains('1.5 meters')));
      expect(uncalibratedHi.text, contains(OpenetraLocalizer.safetyDistanceReplacement('hi-IN')));

      final uncalibratedKn = guard.sanitize(sample, hasCalibratedDepth: false, locale: 'kn-IN');
      expect(uncalibratedKn.wasSanitized, isTrue);
      expect(uncalibratedKn.text, contains(OpenetraLocalizer.safetyDistanceReplacement('kn-IN')));

      final calibrated = guard.sanitize(sample, hasCalibratedDepth: true, locale: 'en-IN');
      expect(calibrated.wasSanitized, isFalse);
      expect(calibrated.text, sample);
    });

    test('replaces counterfeit claims and marks AssistantResponse as wasSafetySanitized', () {
      final resp = AssistantResponse(
        responseId: 'r-1',
        spokenText: 'Verified genuine note in your hand.',
        displaySummary: 'Currency',
        locale: 'kn-IN',
        priority: SpeechPriority.normal,
        hapticPattern: HapticPattern.confirm,
        timestamp: DateTime(2026, 11, 23),
      );
      final sanitized = guard.applyToResponse(resp);
      expect(sanitized.wasSafetySanitized, isTrue);
      expect(sanitized.spokenText.toLowerCase(), isNot(contains('genuine note')));
      expect(
        sanitized.spokenText,
        contains(OpenetraLocalizer.currencyNonCounterfeitDisclaimer('kn-IN')),
      );
    });
  });
}
