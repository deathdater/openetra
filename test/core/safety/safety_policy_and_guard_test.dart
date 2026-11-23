import 'package:flutter_test/flutter_test.dart';
import 'package:openetra/core/domain/entities/entities.dart';
import 'package:openetra/core/safety/openetra_safety_policy.dart';
import 'package:openetra/core/safety/safety_speech_guard.dart';

void main() {
  const guard = SafetySpeechGuard();
  const policy = OpenetraSafetyPolicy();

  test('blocks and rewrites every Section 9.4 prohibited claim', () {
    final cases = [
      'The road is safe to cross now.',
      'The path is clear and completely obstacle-free ahead.',
      'All hazards detected, environment is safe.',
      'There is a chair 2.5 meters away in front of you.',
      'This is a genuine note and not counterfeit.',
      'Openetra replaces your white cane during walking.',
    ];

    for (final unsafe in cases) {
      final res = guard.sanitize(unsafe, hasCalibratedDepth: false);
      expect(res.wasSanitized, isTrue, reason: 'Failed to sanitize: $unsafe');
      final lower = res.text.toLowerCase();
      expect(lower, isNot(contains('safe to cross')));
      expect(lower, isNot(contains('obstacle-free')));
      expect(lower, isNot(contains('path is clear')));
      expect(lower, isNot(contains('2.5 meters')));
      expect(lower, isNot(contains('genuine note')));
      expect(lower, isNot(contains('replaces your white cane')));
    }
  });

  test('preserves calibrated physical distance only when explicitly calibrated', () {
    final res = guard.sanitize(
      'Step 1.5 meters ahead.',
      hasCalibratedDepth: true,
    );
    expect(res.wasSanitized, isFalse);
    expect(res.text, 'Step 1.5 meters ahead.');
  });

  test('marks sanitized AssistantResponse with audit flag', () {
    final raw = AssistantResponse(
      responseId: 'r-1',
      spokenText: 'The way is clear and safe to cross.',
      displaySummary: 'Summary',
      locale: 'en-IN',
      priority: SpeechPriority.normal,
      hapticPattern: HapticPattern.confirm,
      timestamp: DateTime(2026, 11, 23),
    );

    final enforced = policy.enforceResponse(raw);
    expect(enforced.wasSafetySanitized, isTrue);
    expect(enforced.spokenText.toLowerCase(), isNot(contains('way is clear')));
    expect(enforced.spokenText.toLowerCase(), isNot(contains('safe to cross')));
  });
}
