import 'package:flutter/services.dart';
import '../domain/entities/entities.dart';

/// Native haptic feedback channel (`com.openetra.app/haptics`).
class HapticFeedbackService {
  HapticFeedbackService([MethodChannel? channel])
      : _channel = channel ?? const MethodChannel('com.openetra.app/haptics');

  final MethodChannel _channel;

  Future<void> trigger(HapticPattern pattern) async {
    if (pattern == HapticPattern.none) return;
    try {
      await _channel.invokeMethod<void>('vibratePattern', {
        'pattern': pattern.name,
      });
    } on MissingPluginException {
      // Safe no-op during host widget/unit tests.
    }
  }
}
