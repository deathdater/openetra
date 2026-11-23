import '../audio/haptic_feedback_service.dart';
import '../domain/entities/entities.dart';

/// Centralized haptic vocabulary manager for the Assistive Dial and Openetra
/// workflows. Supports global enable/disable, prevents overlapping burst clutter,
/// and delegates safely to native Android VibrationEffect via [HapticFeedbackService].
class HapticFeedbackManager {
  HapticFeedbackManager({
    required HapticFeedbackService service,
    bool enabled = true,
    DateTime Function()? clock,
  })  : _service = service,
        _enabled = enabled,
        _clock = clock ?? DateTime.now;

  final HapticFeedbackService _service;
  final DateTime Function() _clock;
  bool _enabled;
  DateTime? _lastTriggerAt;
  final List<HapticPattern> _history = [];

  bool get isEnabled => _enabled;
  List<HapticPattern> get recentPatterns => List.unmodifiable(_history);

  void setEnabled(bool enabled) {
    _enabled = enabled;
  }

  Future<void> play(HapticPattern pattern, {bool bypassDebounce = false}) async {
    if (!_enabled || pattern == HapticPattern.none) return;
    final now = _clock();
    if (!bypassDebounce &&
        _lastTriggerAt != null &&
        now.difference(_lastTriggerAt!) < const Duration(milliseconds: 45)) {
      return;
    }
    _lastTriggerAt = now;
    _history.add(pattern);
    if (_history.length > 50) _history.removeAt(0);
    await _service.trigger(pattern);
  }

  Future<void> onFocusChanged() => play(HapticPattern.dialFocusTick);
  Future<void> onOptionSelected() =>
      play(HapticPattern.dialSelect, bypassDebounce: true);
  Future<void> onSubmenuEntered() =>
      play(HapticPattern.dialSubmenuEnter, bypassDebounce: true);
  Future<void> onNavigateBack() =>
      play(HapticPattern.dialNavigateBack, bypassDebounce: true);
  Future<void> onRootExitRequested() =>
      play(HapticPattern.dialExitWarn, bypassDebounce: true);
  Future<void> onOperationStarted() =>
      play(HapticPattern.dialOpStart, bypassDebounce: true);
  Future<void> onOperationCompleted() =>
      play(HapticPattern.dialOpComplete, bypassDebounce: true);
  Future<void> onOperationFailed() =>
      play(HapticPattern.dialOpError, bypassDebounce: true);
  Future<void> onEmergencyInitiated() =>
      play(HapticPattern.critical, bypassDebounce: true);
}
