import '../domain/entities/entities.dart';
import 'safety_speech_guard.dart';

/// Top-level safety policy gate auditing all spoken output and degraded alerts.
class OpenetraSafetyPolicy {
  const OpenetraSafetyPolicy({
    this.speechGuard = const SafetySpeechGuard(),
  });

  final SafetySpeechGuard speechGuard;

  AssistantResponse enforceResponse(
    AssistantResponse raw, {
    bool hasCalibratedDepth = false,
  }) {
    return speechGuard.applyToResponse(
      raw,
      hasCalibratedDepth: hasCalibratedDepth,
    );
  }
}
